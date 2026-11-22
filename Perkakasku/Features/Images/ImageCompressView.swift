// xcode: set sdk=iOS

import SwiftUI

/// Local image compressor supporting JPG & HEIC with quality control and real byte comparison.
struct ImageCompressView: View {
    enum OutputFormat: String, CaseIterable, Identifiable {
        case jpeg = "JPG"
        case heic = "HEIC"

        var id: String { rawValue }
        var ext: String { rawValue == "JPG" ? "jpg" : "heic" }
    }

    let tool: Tool

    @EnvironmentObject private var imageService: ImageService
    @EnvironmentObject private var history: HistoryService

    @State private var sourceImage: UIImage?
    @State private var sourceName: String = "photo.jpg"
    @State private var originalBytes: Int64 = 0

    @State private var quality: Double = 0.72
    @State private var outputFormat: OutputFormat = .jpeg

    @State private var isProcessing = false
    @State private var outputImage: UIImage?
    @State private var outputURL: URL?
    @State private var outputBytes: Int64 = 0
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                PhotoImportButton(
                    title: sourceImage == nil ? "Pick Photo from Library" : "Choose Another Photo",
                    maxSelectionCount: 1,
                    compact: sourceImage != nil
                ) { imgs in
                    guard let img = imgs.first else { return }
                    let normalized = imageService.normalizedOrientation(img)
                    sourceImage = normalized
                    sourceName = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
                    originalBytes = Int64(normalized.pngData()?.count ?? normalized.jpegData(compressionQuality: 0.95)?.count ?? 0)
                    outputImage = nil
                    outputURL = nil
                    errorMessage = nil
                    PKHaptics.selection()
                }

                FileImportButton(
                    title: "Or Select Image File",
                    hint: "Import JPG, PNG, HEIC, or WebP from Files",
                    icon: "folder.badge.plus",
                    allowedUTIs: FileUtils.imageUTIs,
                    allowsMultiple: false,
                    compact: true,
                    onError: { errorMessage = $0 }
                ) { urls in
                    guard let url = urls.first,
                          let data = try? LocalFileManager.shared.read(from: url),
                          let img = UIImage(data: data) else {
                        errorMessage = "Could not load the selected image file."
                        return
                    }
                    sourceImage = imageService.normalizedOrientation(img)
                    sourceName = url.lastPathComponent
                    originalBytes = Int64(data.count)
                    outputImage = nil
                    outputURL = nil
                    errorMessage = nil
                    PKHaptics.selection()
                }
            }

            if let sourceImage {
                ToolSettingsCard(
                    title: "Compression Controls",
                    badge: ByteCountFormatter.string(fromByteCount: originalBytes, countStyle: .file)
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(uiImage: sourceImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(PKColors.border, lineWidth: 1))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(sourceName)
                                    .font(PKFont.body(.subheadline, weight: .semibold))
                                    .lineLimit(1)
                                Text("\(Int(sourceImage.size.width)) × \(Int(sourceImage.size.height)) px")
                                    .font(PKFont.mono(.caption, weight: .medium))
                                    .foregroundStyle(PKColors.textMuted)
                                Text("Source: \(ByteCountFormatter.string(fromByteCount: originalBytes, countStyle: .file))")
                                    .font(PKFont.mono(.caption2, weight: .regular))
                                    .foregroundStyle(PKColors.textSecondary)
                            }
                            Spacer()
                        }

                        Picker("Format", selection: $outputFormat) {
                            ForEach(OutputFormat.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Quality")
                                    .font(PKFont.body(.caption, weight: .semibold))
                                Spacer()
                                Text("\(Int(quality * 100))%")
                                    .font(PKFont.mono(.caption, weight: .bold))
                                    .foregroundStyle(PKColors.brand)
                            }
                            Slider(value: $quality, in: 0.15...0.95, step: 0.05)
                        }

                        PrimaryButton(
                            title: "Compress Image",
                            icon: "arrow.down.right.and.arrow.up.left",
                            isLoading: isProcessing
                        ) {
                            compressImage()
                        }
                    }
                }
            }

            if isProcessing {
                LoadingView(message: "Re-encoding image locally…")
            }

            if let errorMessage {
                ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }

            if let outputURL, let outputImage {
                VStack(alignment: .leading, spacing: 14) {
                    ToolResultCard(
                        title: "Image Compressed",
                        subtitle: "Compressed locally in \(outputFormat.rawValue) format.",
                        fileURL: outputURL,
                        originalBytes: originalBytes,
                        outputBytes: outputBytes,
                        metrics: [
                            ("Quality", "\(Int(quality * 100))%"),
                            ("Dimensions", "\(Int(outputImage.size.width))×\(Int(outputImage.size.height))"),
                        ],
                        exportLabel: "Export Compressed Image",
                        imageToSave: outputImage
                    )

                    Image(uiImage: outputImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous).strokeBorder(PKColors.border, lineWidth: 1))
                }
            }
        }
    }

    private func compressImage() {
        guard let sourceImage else { return }
        isProcessing = true
        errorMessage = nil
        outputURL = nil
        outputImage = nil

        let format: ImageService.Format = outputFormat == .jpeg ? .jpeg(quality: quality) : .heic(quality: quality)
        guard let data = imageService.convert(image: sourceImage, to: format) else {
            errorMessage = "Failed to encode compressed image."
            isProcessing = false
            PKHaptics.error()
            return
        }

        let outName = FileUtils.outputFileName(input: sourceName, suffix: "_compressed", ext: outputFormat.ext)
        let dest = LocalFileManager.shared.documentsURL(for: outName)

        do {
            try LocalFileManager.shared.write(data: data, to: dest)
            outputURL = dest
            outputImage = UIImage(data: data) ?? sourceImage
            outputBytes = Int64(data.count)

            history.record(
                tool: tool,
                inputFileName: sourceName,
                outputFileName: dest.lastPathComponent,
                outputURL: dest,
                status: .completed,
                fileSize: outputBytes
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isProcessing = false
    }
}
