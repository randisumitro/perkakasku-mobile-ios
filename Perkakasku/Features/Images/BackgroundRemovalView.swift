// xcode: set sdk=iOS

import SwiftUI

/// On-device Apple Vision subject cutout workbench with interactive Before/After split comparator
/// and matte color options (Transparent PNG, White, Red ID, Blue ID, or Custom).
struct BackgroundRemovalView: View {
    enum MatteOption: String, CaseIterable, Identifiable {
        case transparent = "Transparent"
        case white = "White"
        case red = "ID Red"
        case blue = "ID Blue"
        case custom = "Custom"

        var id: String { rawValue }
    }

    let tool: Tool

    @EnvironmentObject private var imageService: ImageService
    @EnvironmentObject private var history: HistoryService

    @State private var sourceImage: UIImage?
    @State private var sourceName: String = "photo.png"

    @State private var cutoutImage: UIImage?
    @State private var compositedImage: UIImage?
    @State private var outputURL: URL?
    @State private var engineUsed: String = "Apple Vision"

    @State private var matteOption: MatteOption = .transparent
    @State private var customColor: Color = Color(red: 0.96, green: 0.95, blue: 0.93)
    @State private var splitRatio: Double = 0.5

    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                PhotoImportButton(
                    title: sourceImage == nil ? "Pick Subject Photo" : "Choose Another Photo",
                    maxSelectionCount: 1,
                    compact: sourceImage != nil
                ) { imgs in
                    guard let img = imgs.first else { return }
                    let norm = imageService.normalizedOrientation(img)
                    sourceImage = norm
                    sourceName = "photo_\(Int(Date().timeIntervalSince1970)).png"
                    cutoutImage = nil
                    compositedImage = nil
                    outputURL = nil
                    errorMessage = nil
                    Task { await runSegmentation(on: norm) }
                }

                FileImportButton(
                    title: "Or Import Image File",
                    hint: "Runs 100% on-device via Apple Vision neural segmentation",
                    icon: "folder.badge.plus",
                    allowedUTIs: FileUtils.imageUTIs,
                    allowsMultiple: false,
                    compact: true,
                    onError: { errorMessage = $0 }
                ) { urls in
                    guard let url = urls.first,
                          let data = try? LocalFileManager.shared.read(from: url),
                          let img = UIImage(data: data) else {
                        errorMessage = "Could not open image file."
                        return
                    }
                    let norm = imageService.normalizedOrientation(img)
                    sourceImage = norm
                    sourceName = url.lastPathComponent
                    cutoutImage = nil
                    compositedImage = nil
                    outputURL = nil
                    errorMessage = nil
                    Task { await runSegmentation(on: norm) }
                }
            }

            if isProcessing {
                LoadingView(message: "Detecting foreground subject mask with Apple Vision…")
            }

            if let errorMessage {
                ErrorView(
                    message: errorMessage,
                    onRetry: sourceImage != nil ? {
                        if let img = sourceImage {
                            Task { await runSegmentation(on: img) }
                        }
                    } : nil,
                    onDismiss: { self.errorMessage = nil }
                )
            }

            if let sourceImage, let compositedImage {
                ToolSettingsCard(
                    title: "Cutout Comparison & Backdrop",
                    badge: engineUsed
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        // Interactive Before / After comparator over checkerboard
                        GeometryReader { geo in
                            let w = geo.size.width
                            let h: CGFloat = 290
                            ZStack {
                                CheckerboardBackground()

                                Image(uiImage: compositedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: w, height: h)

                                Image(uiImage: sourceImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: w, height: h)
                                    .mask(
                                        HStack(spacing: 0) {
                                            Rectangle()
                                                .frame(width: w * splitRatio)
                                            Spacer(minLength: 0)
                                        }
                                    )

                                // Divider handle
                                Rectangle()
                                    .fill(.white)
                                    .frame(width: 2, height: h)
                                    .shadow(radius: 2)
                                    .position(x: w * splitRatio, y: h / 2)

                                Circle()
                                    .fill(PKColors.brandVivid)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "chevron.left.chevron.right")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                    )
                                    .shadow(radius: 4)
                                    .position(x: w * splitRatio, y: h / 2)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: PKRadius.sm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: PKRadius.sm, style: .continuous)
                                    .strokeBorder(PKColors.border, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        splitRatio = min(1.0, max(0.0, value.location.x / max(1, w)))
                                    }
                            )
                        }
                        .frame(height: 290)

                        HStack {
                            Text("Before")
                                .font(PKFont.mono(.caption2, weight: .bold))
                                .foregroundStyle(PKColors.textMuted)
                            Slider(value: $splitRatio, in: 0...1)
                            Text("After Cutout")
                                .font(PKFont.mono(.caption2, weight: .bold))
                                .foregroundStyle(PKColors.brand)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Backdrop Matte")
                                .font(PKFont.body(.caption, weight: .semibold))
                                .foregroundStyle(PKColors.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(MatteOption.allCases) { opt in
                                        let active = matteOption == opt
                                        Button {
                                            matteOption = opt
                                            PKHaptics.selection()
                                            applyMatteAndSave()
                                        } label: {
                                            Text(opt.rawValue)
                                                .font(PKFont.body(.caption, weight: .semibold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .foregroundStyle(active ? .white : PKColors.textPrimary)
                                                .background(active ? PKColors.brandVivid : PKColors.backgroundInset, in: Capsule())
                                                .overlay(Capsule().strokeBorder(active ? Color.clear : PKColors.border, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            if matteOption == .custom {
                                ColorPicker("Matte Color", selection: $customColor, supportsOpacity: false)
                                    .onChange(of: customColor) { _, _ in
                                        applyMatteAndSave()
                                    }
                            }
                        }
                    }
                }
            }

            if let outputURL, let compositedImage {
                ToolResultCard(
                    title: "Background Removed",
                    subtitle: matteOption == .transparent
                        ? "Saved with alpha transparency as PNG."
                        : "Composited cleanly onto \(matteOption.rawValue) backdrop.",
                    fileURL: outputURL,
                    outputBytes: outputURL.fileSize,
                    metrics: [
                        ("Engine", engineUsed),
                        ("Resolution", "\(Int(compositedImage.size.width))×\(Int(compositedImage.size.height))"),
                    ],
                    exportLabel: "Export Cutout PNG",
                    imageToSave: compositedImage
                )
            }
        }
    }

    private func runSegmentation(on image: UIImage) async {
        isProcessing = true
        errorMessage = nil

        do {
            let result = try await VisionSegmentationService.shared.removeBackground(from: image)
            cutoutImage = result.cutoutImage
            engineUsed = result.engineName
            applyMatteAndSave()
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isProcessing = false
    }

    private func applyMatteAndSave() {
        guard let cutoutImage else { return }
        let uiMatte: UIColor? = switch matteOption {
        case .transparent: nil
        case .white: .white
        case .red: UIColor(red: 0xDB / 255.0, green: 0x1B / 255.0, blue: 0x24 / 255.0, alpha: 1)
        case .blue: UIColor(red: 0x0A / 255.0, green: 0x4C / 255.0, blue: 0xA3 / 255.0, alpha: 1)
        case .custom: UIColor(customColor)
        }

        guard let result = VisionSegmentationService.shared.compositeWithMatte(
            cutout: cutoutImage,
            backgroundColor: uiMatte,
            asPNG: true
        ) else { return }

        let suffix = matteOption == .transparent ? "_cutout" : "_\(matteOption.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let outName = FileUtils.outputFileName(input: sourceName, suffix: suffix, ext: "png")
        let dest = LocalFileManager.shared.documentsURL(for: outName)

        do {
            try LocalFileManager.shared.write(data: result.data, to: dest)
            compositedImage = result.image
            outputURL = dest
            history.record(
                tool: tool,
                inputFileName: sourceName,
                outputFileName: dest.lastPathComponent,
                outputURL: dest,
                status: .completed,
                fileSize: Int64(result.data.count)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
