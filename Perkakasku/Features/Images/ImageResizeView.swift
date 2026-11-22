// xcode: set sdk=iOS

import SwiftUI

/// Exact pixel resizer & format converter (JPG / PNG / HEIC) running locally on device.
struct ImageResizeView: View {
    enum FormatChoice: String, CaseIterable, Identifiable {
        case jpg = "JPG"
        case png = "PNG"
        case heic = "HEIC"

        var id: String { rawValue }
        var ext: String { rawValue.lowercased() }
    }

    let tool: Tool

    @EnvironmentObject private var imageService: ImageService
    @EnvironmentObject private var history: HistoryService

    @State private var sourceImage: UIImage?
    @State private var sourceName: String = "image.png"
    @State private var targetWidth: Int = 1080
    @State private var targetHeight: Int = 1080
    @State private var lockAspectRatio = true
    @State private var format: FormatChoice = .jpg
    @State private var quality: Double = 0.9

    @State private var isProcessing = false
    @State private var outputImage: UIImage?
    @State private var outputURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                PhotoImportButton(
                    title: sourceImage == nil ? "Pick Photo to Resize" : "Choose Another Photo",
                    maxSelectionCount: 1,
                    compact: sourceImage != nil
                ) { imgs in
                    guard let img = imgs.first else { return }
                    loadSource(img, name: "photo_\(Int(Date().timeIntervalSince1970)).png")
                }

                FileImportButton(
                    title: "Or Import Image File",
                    hint: "Select JPG, PNG, HEIC, or WebP from Files",
                    icon: "folder.badge.plus",
                    allowedUTIs: FileUtils.imageUTIs,
                    allowsMultiple: false,
                    compact: true,
                    onError: { errorMessage = $0 }
                ) { urls in
                    guard let url = urls.first,
                          let data = try? LocalFileManager.shared.read(from: url),
                          let img = UIImage(data: data) else {
                        errorMessage = "Could not load selected image."
                        return
                    }
                    loadSource(img, name: url.lastPathComponent)
                }
            }

            if let sourceImage {
                ToolSettingsCard(
                    title: "Target Dimensions & Format",
                    badge: "\(Int(sourceImage.size.width)) × \(Int(sourceImage.size.height)) src"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Width (px)")
                                    .font(PKFont.body(.caption, weight: .semibold))
                                    .foregroundStyle(PKColors.textSecondary)
                                TextField("Width", value: $targetWidth, format: .number)
                                    .keyboardType(.numberPad)
                                    .font(PKFont.mono(.subheadline, weight: .bold))
                                    .padding(10)
                                    .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                                    .onChange(of: targetWidth) { _, newW in
                                        if lockAspectRatio, sourceImage.size.width > 0 {
                                            let ratio = sourceImage.size.height / sourceImage.size.width
                                            targetHeight = max(1, Int(round(Double(newW) * ratio)))
                                        }
                                    }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Height (px)")
                                    .font(PKFont.body(.caption, weight: .semibold))
                                    .foregroundStyle(PKColors.textSecondary)
                                TextField("Height", value: $targetHeight, format: .number)
                                    .keyboardType(.numberPad)
                                    .font(PKFont.mono(.subheadline, weight: .bold))
                                    .padding(10)
                                    .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                                    .onChange(of: targetHeight) { _, newH in
                                        if lockAspectRatio, sourceImage.size.height > 0 {
                                            let ratio = sourceImage.size.width / sourceImage.size.height
                                            targetWidth = max(1, Int(round(Double(newH) * ratio)))
                                        }
                                    }
                            }
                        }

                        Toggle("Lock original aspect ratio", isOn: $lockAspectRatio)
                            .font(PKFont.body(.subheadline))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                presetPill("50%", action: {
                                    lockAspectRatio = false
                                    targetWidth = max(1, Int(sourceImage.size.width * 0.5))
                                    targetHeight = max(1, Int(sourceImage.size.height * 0.5))
                                })
                                presetPill("1920px HD", action: { applyMaxWidth(1920) })
                                presetPill("1280px Web", action: { applyMaxWidth(1280) })
                                presetPill("1080×1080", action: {
                                    lockAspectRatio = false
                                    targetWidth = 1080
                                    targetHeight = 1080
                                })
                            }
                        }

                        Picker("Output Format", selection: $format) {
                            ForEach(FormatChoice.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)

                        if format != .png {
                            HStack {
                                Text("Quality: \(Int(quality * 100))%")
                                    .font(PKFont.mono(.caption, weight: .medium))
                                Slider(value: $quality, in: 0.3...1.0, step: 0.05)
                            }
                        }

                        PrimaryButton(
                            title: "Resize & Convert",
                            icon: "arrow.up.left.and.arrow.down.right",
                            isLoading: isProcessing
                        ) {
                            processResize()
                        }
                    }
                }
            }

            if isProcessing {
                LoadingView(message: "Rendering resized image…")
            }

            if let errorMessage {
                ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }

            if let outputURL, let outputImage {
                VStack(alignment: .leading, spacing: 14) {
                    ToolResultCard(
                        title: "Image Ready",
                        subtitle: "Resized & exported as \(format.rawValue).",
                        fileURL: outputURL,
                        outputBytes: outputURL.fileSize,
                        metrics: [
                            ("Output Size", "\(Int(outputImage.size.width)) × \(Int(outputImage.size.height)) px"),
                            ("Format", format.rawValue),
                        ],
                        exportLabel: "Export \(format.rawValue)",
                        imageToSave: outputImage
                    )

                    Image(uiImage: outputImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: PKRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: PKRadius.md).strokeBorder(PKColors.border, lineWidth: 1))
                }
            }
        }
    }

    private func presetPill(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            PKHaptics.selection()
            action()
        } label: {
            Text(title)
                .font(PKFont.mono(.caption, weight: .semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(PKColors.backgroundInset, in: Capsule())
                .overlay(Capsule().strokeBorder(PKColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func loadSource(_ img: UIImage, name: String) {
        let normalized = imageService.normalizedOrientation(img)
        sourceImage = normalized
        sourceName = name
        targetWidth = max(1, Int(normalized.size.width))
        targetHeight = max(1, Int(normalized.size.height))
        outputURL = nil
        outputImage = nil
        errorMessage = nil
        PKHaptics.selection()
    }

    private func applyMaxWidth(_ maxW: Int) {
        guard let sourceImage, sourceImage.size.width > 0 else { return }
        let ratio = sourceImage.size.height / sourceImage.size.width
        targetWidth = maxW
        targetHeight = max(1, Int(round(Double(maxW) * ratio)))
    }

    private func processResize() {
        guard let sourceImage else { return }
        guard targetWidth > 0, targetHeight > 0, targetWidth <= 8000, targetHeight <= 8000 else {
            errorMessage = "Dimensions must be between 1 and 8000 pixels."
            PKHaptics.error()
            return
        }

        isProcessing = true
        errorMessage = nil
        outputURL = nil

        let size = CGSize(width: targetWidth, height: targetHeight)
        guard let resized = imageService.resize(image: sourceImage, to: size, opaque: format != .png) else {
            errorMessage = "Failed to resize image."
            isProcessing = false
            PKHaptics.error()
            return
        }

        let fmt: ImageService.Format = switch format {
        case .jpg: .jpeg(quality: quality)
        case .png: .png
        case .heic: .heic(quality: quality)
        }
        guard let data = imageService.convert(image: resized, to: fmt) else {
            errorMessage = "Failed to convert image to \(format.rawValue)."
            isProcessing = false
            PKHaptics.error()
            return
        }

        let outName = FileUtils.outputFileName(input: sourceName, suffix: "_\(targetWidth)x\(targetHeight)", ext: format.ext)
        let dest = LocalFileManager.shared.documentsURL(for: outName)

        do {
            try LocalFileManager.shared.write(data: data, to: dest)
            outputURL = dest
            outputImage = UIImage(data: data) ?? resized
            history.record(
                tool: tool,
                inputFileName: sourceName,
                outputFileName: dest.lastPathComponent,
                outputURL: dest,
                status: .completed,
                fileSize: Int64(data.count)
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isProcessing = false
    }
}
