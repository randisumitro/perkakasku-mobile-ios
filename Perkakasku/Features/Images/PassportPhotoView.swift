// xcode: set sdk=iOS

import SwiftUI

/// Interactive 300 DPI Passport & ID Photo Studio (2x3, 3x4, 4x6 cm) with framing guide,
/// pan/zoom/rotate controls, optional Vision background cutout, and Red/Blue/White backdrops.
struct PassportPhotoView: View {
    enum BackdropChoice: String, CaseIterable, Identifiable {
        case original = "Original"
        case red = "Red"
        case blue = "Blue"
        case white = "White"
        case custom = "Custom"

        var id: String { rawValue }
    }

    let tool: Tool

    @EnvironmentObject private var imageService: ImageService
    @EnvironmentObject private var history: HistoryService

    @State private var originalImage: UIImage?
    @State private var cutoutImage: UIImage?
    @State private var sourceName: String = "portrait.jpg"

    @State private var sizePreset: PassportSizePreset = .size3x4
    @State private var backdrop: BackdropChoice = .red
    @State private var customBgColor: Color = .white
    @State private var showFramingGuide = true

    @State private var zoom: Double = 1.0
    @State private var offsetX: Double = 0
    @State private var offsetY: Double = 0
    @State private var rotationDegrees: Double = 0

    @State private var isCuttingOut = false
    @State private var isProcessing = false
    @State private var renderedPhoto: UIImage?
    @State private var outputURL: URL?
    @State private var errorMessage: String?

    private var activeSourceImage: UIImage? {
        if backdrop != .original, let cutoutImage {
            return cutoutImage
        }
        return originalImage
    }

    private var activeBackdropUIColor: UIColor? {
        switch backdrop {
        case .original: return .white
        case .red: return UIColor(red: 0xDB / 255.0, green: 0x1B / 255.0, blue: 0x24 / 255.0, alpha: 1)
        case .blue: return UIColor(red: 0x0A / 255.0, green: 0x4C / 255.0, blue: 0xA3 / 255.0, alpha: 1)
        case .white: return .white
        case .custom: return UIColor(customBgColor)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                PhotoImportButton(
                    title: originalImage == nil ? "Pick Portrait Photo" : "Choose Another Portrait",
                    maxSelectionCount: 1,
                    compact: originalImage != nil
                ) { imgs in
                    guard let img = imgs.first else { return }
                    loadPortrait(img, name: "portrait_\(Int(Date().timeIntervalSince1970)).jpg")
                }

                FileImportButton(
                    title: "Or Import Portrait File",
                    hint: "JPG, PNG, or HEIC portrait photo",
                    icon: "folder.badge.plus",
                    allowedUTIs: FileUtils.imageUTIs,
                    allowsMultiple: false,
                    compact: true,
                    onError: { errorMessage = $0 }
                ) { urls in
                    guard let url = urls.first,
                          let data = try? LocalFileManager.shared.read(from: url),
                          let img = UIImage(data: data) else {
                        errorMessage = "Could not load portrait file."
                        return
                    }
                    loadPortrait(img, name: url.lastPathComponent)
                }
            }

            if originalImage != nil {
                studioPreviewCard
                studioControlsCard
            }

            if isCuttingOut {
                LoadingView(message: "Separating portrait from original background…")
            }

            if isProcessing {
                LoadingView(message: "Rendering 300 DPI print-ready ID photo…")
            }

            if let errorMessage {
                ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }

            if let outputURL, let renderedPhoto {
                let targetPx = sizePreset.pixelSize300DPI
                ToolResultCard(
                    title: "Passport Photo Ready",
                    subtitle: "Formatted at 300 DPI for crisp lab or official online upload.",
                    fileURL: outputURL,
                    outputBytes: outputURL.fileSize,
                    metrics: [
                        ("Size", sizePreset.label),
                        ("Dimensions", "\(Int(targetPx.width))×\(Int(targetPx.height)) px · 300 DPI"),
                    ],
                    exportLabel: "Export 300 DPI JPG",
                    imageToSave: renderedPhoto
                )
            }
        }
    }

    private var studioPreviewCard: some View {
        ToolSettingsCard(
            title: "Studio Framing",
            subtitle: "Drag to position · Adjust zoom & head guide",
            badge: sizePreset.label
        ) {
            VStack(spacing: 12) {
                let previewH: CGFloat = 250
                let previewW = previewH * sizePreset.aspectRatio

                ZStack {
                    if let activeSourceImage {
                        let rendered = imageService.renderPassportPhoto(
                            image: activeSourceImage,
                            preset: sizePreset,
                            backgroundColor: activeBackdropUIColor,
                            zoom: zoom,
                            offsetX: offsetX,
                            offsetY: offsetY,
                            rotationDegrees: rotationDegrees,
                            asPNG: false
                        )?.image

                        if let rendered {
                            Image(uiImage: rendered)
                                .resizable()
                                .scaledToFill()
                                .frame(width: previewW, height: previewH)
                        }
                    }

                    if showFramingGuide {
                        PassportGuideOverlay()
                            .frame(width: previewW, height: previewH)
                    }
                }
                .frame(width: previewW, height: previewH)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(PKColors.borderStrong, lineWidth: 1.5)
                )
                .frame(maxWidth: .infinity)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offsetX = max(-1, min(1, offsetX + Double(value.translation.width) / 400.0))
                            offsetY = max(-1, min(1, offsetY + Double(value.translation.height) / 400.0))
                        }
                )

                Toggle("Show official head & shoulder guide", isOn: $showFramingGuide)
                    .font(PKFont.body(.caption, weight: .semibold))
            }
        }
    }

    private var studioControlsCard: some View {
        ToolSettingsCard(title: "Dimensions, Cutout & Backdrop") {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Print Size", selection: $sizePreset) {
                    ForEach(PassportSizePreset.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)

                Text(sizePreset.hint)
                    .font(PKFont.mono(.caption2, weight: .medium))
                    .foregroundStyle(PKColors.textMuted)

                Button {
                    Task { await runPortraitCutout() }
                } label: {
                    Label(
                        cutoutImage == nil ? "Auto-Remove Original Background" : "Background Removed (Tap to Re-Run)",
                        systemImage: cutoutImage == nil ? "person.crop.rectangle" : "checkmark.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PKPillButtonStyle(variant: cutoutImage == nil ? .ink : .secondary, compact: true))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Backdrop Color")
                        .font(PKFont.body(.caption, weight: .semibold))
                        .foregroundStyle(PKColors.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(BackdropChoice.allCases) { bg in
                                let active = backdrop == bg
                                Button {
                                    backdrop = bg
                                    PKHaptics.selection()
                                    if bg != .original && cutoutImage == nil {
                                        Task { await runPortraitCutout() }
                                    }
                                } label: {
                                    Text(bg.rawValue)
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

                    if backdrop == .custom {
                        ColorPicker("Custom Color", selection: $customBgColor, supportsOpacity: false)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Zoom: \(String(format: "%.2fx", zoom))")
                        .font(PKFont.mono(.caption, weight: .medium))
                    Slider(value: $zoom, in: 1.0...2.8, step: 0.05)
                }

                HStack(spacing: 10) {
                    Button {
                        rotationDegrees = Double((Int(rotationDegrees) + 90) % 360)
                        PKHaptics.selection()
                    } label: {
                        Label("Rotate 90°", systemImage: "rotate.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))

                    Button {
                        zoom = 1.0
                        offsetX = 0
                        offsetY = 0
                        rotationDegrees = 0
                        PKHaptics.selection()
                    } label: {
                        Label("Reset Framing", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))
                }

                PrimaryButton(
                    title: "Generate 300 DPI Passport Photo",
                    icon: "person.text.rectangle.fill",
                    isLoading: isProcessing
                ) {
                    exportPassportPhoto()
                }
            }
        }
    }

    private func loadPortrait(_ img: UIImage, name: String) {
        originalImage = imageService.normalizedOrientation(img)
        cutoutImage = nil
        sourceName = name
        renderedPhoto = nil
        outputURL = nil
        errorMessage = nil
        zoom = 1.0
        offsetX = 0
        offsetY = 0
        rotationDegrees = 0
        backdrop = .original
        PKHaptics.selection()
    }

    private func runPortraitCutout() async {
        guard let originalImage else { return }
        isCuttingOut = true
        errorMessage = nil

        do {
            let result = try await VisionSegmentationService.shared.removeBackground(from: originalImage)
            cutoutImage = result.cutoutImage
            if backdrop == .original {
                backdrop = .red
            }
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isCuttingOut = false
    }

    private func exportPassportPhoto() {
        guard let src = activeSourceImage else { return }
        isProcessing = true
        errorMessage = nil

        guard let result = imageService.renderPassportPhoto(
            image: src,
            preset: sizePreset,
            backgroundColor: activeBackdropUIColor,
            zoom: zoom,
            offsetX: offsetX,
            offsetY: offsetY,
            rotationDegrees: rotationDegrees,
            asPNG: false,
            quality: 0.94,
            dpi: 300
        ) else {
            errorMessage = "Could not render 300 DPI passport photo."
            isProcessing = false
            PKHaptics.error()
            return
        }

        let outName = FileUtils.outputFileName(
            input: sourceName,
            suffix: "_pasfoto_\(sizePreset.rawValue)_300dpi",
            ext: "jpg"
        )
        let dest = LocalFileManager.shared.documentsURL(for: outName)

        do {
            try LocalFileManager.shared.write(data: result.data, to: dest)
            renderedPhoto = result.image
            outputURL = dest

            history.record(
                tool: tool,
                inputFileName: sourceName,
                outputFileName: dest.lastPathComponent,
                outputURL: dest,
                status: .completed,
                fileSize: Int64(result.data.count)
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isProcessing = false
    }
}

private struct PassportGuideOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Ellipse()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: w * 0.56, height: h * 0.48)
                    .position(x: w * 0.5, y: h * 0.38)

                Path { p in
                    p.move(to: CGPoint(x: w * 0.14, y: h * 0.88))
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.86, y: h * 0.88),
                        control: CGPoint(x: w * 0.5, y: h * 0.64)
                    )
                }
                .stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            }
        }
        .allowsHitTesting(false)
    }
}
