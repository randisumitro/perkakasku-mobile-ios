// xcode: set sdk=iOS

import SwiftUI
import UniformTypeIdentifiers

/// Multi-file HEIC -> JPG converter supporting local ImageIO and optional sandbox backend,
/// EXIF/GPS metadata stripping, individual downloads, and ZIP packaging.
struct HEICToJPGView: View {
    enum EngineChoice: String, CaseIterable, Identifiable {
        case local = "On-Device (Instant)"
        case server = "Sandbox Server"

        var id: String { rawValue }
    }

    private struct SourceFile: Identifiable {
        let id = UUID()
        let name: String
        let data: Data
    }

    private struct ConvertedOutput: Identifiable {
        let id = UUID()
        let url: URL
        let image: UIImage
        let bytes: Int64
    }

    let tool: Tool

    @EnvironmentObject private var imageService: ImageService
    @EnvironmentObject private var apiService: APIService
    @EnvironmentObject private var history: HistoryService

    @State private var inputs: [SourceFile] = []
    @State private var quality: Double = 0.90
    @State private var stripMetadata = true
    @State private var engine: EngineChoice = .local

    @State private var isProcessing = false
    @State private var outputs: [ConvertedOutput] = []
    @State private var zipURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                FileImportButton(
                    title: inputs.isEmpty ? "Select HEIC / HEIF Files" : "Add More HEIC Files",
                    hint: "Batch convert iPhone HEIC photos to universal JPG",
                    icon: "arrow.triangle.2.circlepath.camera.fill",
                    allowedUTIs: [UTType.heic.identifier, UTType.heif.identifier, UTType.image.identifier],
                    allowsMultiple: true,
                    compact: !inputs.isEmpty,
                    onError: { errorMessage = $0 }
                ) { urls in
                    for url in urls {
                        if let data = try? LocalFileManager.shared.read(from: url) {
                            inputs.append(SourceFile(name: url.lastPathComponent, data: data))
                        }
                    }
                    outputs = []
                    zipURL = nil
                    errorMessage = nil
                    PKHaptics.selection()
                }

                PhotoImportButton(
                    title: "Or Pick from Photo Library",
                    maxSelectionCount: 10,
                    compact: true
                ) { imgs in
                    for (idx, img) in imgs.enumerated() {
                        if let heicData = imageService.convert(image: img, to: .heic(quality: 0.95)) ?? img.jpegData(compressionQuality: 0.95) {
                            inputs.append(SourceFile(name: "photo_\(inputs.count + idx + 1).heic", data: heicData))
                        }
                    }
                    outputs = []
                    zipURL = nil
                }
            }

            if !inputs.isEmpty {
                ToolSettingsCard(
                    title: "Conversion Settings",
                    badge: "\(inputs.count) file\(inputs.count == 1 ? "" : "s")"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(inputs.enumerated()), id: \.element.id) { idx, item in
                            ToolFileItemRow(
                                fileName: item.name,
                                meta: ByteCountFormatter.string(fromByteCount: Int64(item.data.count), countStyle: .file),
                                icon: "photo.fill"
                            ) {
                                inputs.remove(at: idx)
                                outputs = []
                                zipURL = nil
                            }
                        }

                        Picker("Engine", selection: $engine) {
                            ForEach(EngineChoice.allCases) { e in
                                Text(e.rawValue).tag(e)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("JPG Quality")
                                    .font(PKFont.body(.caption, weight: .semibold))
                                Spacer()
                                Text("\(Int(quality * 100))%")
                                    .font(PKFont.mono(.caption, weight: .bold))
                                    .foregroundStyle(PKColors.brand)
                            }
                            Slider(value: $quality, in: 0.5...1.0, step: 0.05)
                        }

                        Toggle("Strip EXIF & GPS location metadata", isOn: $stripMetadata)
                            .font(PKFont.body(.subheadline))

                        PrimaryButton(
                            title: "Convert \(inputs.count) File\(inputs.count == 1 ? "" : "s") to JPG",
                            icon: "arrow.triangle.2.circlepath",
                            isLoading: isProcessing
                        ) {
                            Task { await convertAll() }
                        }
                    }
                }
            }

            if isProcessing {
                LoadingView(message: engine == .local ? "Converting HEIC images natively…" : "Converting via Perkakasku sandbox…")
            }

            if let errorMessage {
                ErrorView(
                    message: errorMessage,
                    onRetry: { Task { await convertAll() } },
                    onDismiss: { self.errorMessage = nil }
                )
            }

            if !outputs.isEmpty {
                let primary = zipURL ?? outputs.first?.url
                ToolResultCard(
                    title: "Conversion Complete",
                    subtitle: outputs.count > 1
                        ? "Converted \(outputs.count) JPGs and bundled them into a ZIP archive."
                        : "Converted cleanly to JPG.",
                    fileURL: primary,
                    outputBytes: primary?.fileSize,
                    metrics: [
                        ("Converted", "\(outputs.count) JPG\(outputs.count == 1 ? "" : "s")"),
                        ("Metadata", stripMetadata ? "EXIF Stripped" : "Preserved"),
                    ],
                    exportLabel: outputs.count > 1 ? "Export All (.ZIP)" : "Export JPG",
                    imageToSave: outputs.count == 1 ? outputs.first?.image : nil
                )

                if outputs.count > 1 {
                    ToolSettingsCard(title: "Individual JPG Outputs", badge: "\(outputs.count)") {
                        VStack(spacing: 8) {
                            ForEach(outputs) { item in
                                HStack(spacing: 10) {
                                    Image(uiImage: item.image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.url.lastPathComponent)
                                            .font(PKFont.mono(.caption, weight: .semibold))
                                            .lineLimit(1)
                                        Text(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))
                                            .font(PKFont.mono(.caption2, weight: .regular))
                                            .foregroundStyle(PKColors.textMuted)
                                    }
                                    Spacer()
                                    ShareLink(item: item.url) {
                                        Image(systemName: "square.and.arrow.up")
                                            .padding(8)
                                            .background(PKColors.brandSoft, in: Circle())
                                            .foregroundStyle(PKColors.brand)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .pkInsetCard(radius: PKRadius.sm, padding: 8)
                            }
                        }
                    }
                }
            }
        }
    }

    private func convertAll() async {
        guard !inputs.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        outputs = []
        zipURL = nil

        var produced: [ConvertedOutput] = []
        var entries: [ZIPBuilder.Entry] = []

        do {
            for item in inputs {
                let jpgData: Data
                switch engine {
                case .local:
                    guard let converted = imageService.heicToJPG(
                        data: item.data,
                        quality: quality,
                        stripMetadata: stripMetadata
                    ) else {
                        throw APIError.serverError(422, "Failed to decode \(item.name) locally.")
                    }
                    jpgData = converted

                case .server:
                    let multipart = MultipartFile(
                        fieldName: "file",
                        fileName: item.name,
                        mimeType: "image/heic",
                        data: item.data
                    )
                    let decoded = try await apiService.heicToJPG(
                        file: multipart,
                        quality: quality,
                        stripMetadata: stripMetadata
                    )
                    jpgData = decoded.data
                }

                let outName = FileUtils.outputFileName(input: item.name, suffix: "", ext: "jpg")
                let dest = LocalFileManager.shared.documentsURL(for: outName)
                try LocalFileManager.shared.write(data: jpgData, to: dest)
                let preview = UIImage(data: jpgData) ?? UIImage()
                produced.append(ConvertedOutput(url: dest, image: preview, bytes: Int64(jpgData.count)))
                entries.append(ZIPBuilder.Entry(fileName: outName, data: jpgData))
            }

            outputs = produced
            if entries.count > 1 {
                let zipData = try ZIPBuilder.buildArchive(entries: entries)
                let zURL = LocalFileManager.shared.documentsURL(for: "heic_converted_\(Int(Date().timeIntervalSince1970)).zip")
                try LocalFileManager.shared.write(data: zipData, to: zURL)
                zipURL = zURL
            }

            let recordTarget = zipURL ?? produced.first?.url
            history.record(
                tool: tool,
                inputFileName: inputs.count == 1 ? inputs[0].name : "\(inputs.count) HEIC files",
                outputFileName: recordTarget?.lastPathComponent,
                outputURL: recordTarget,
                status: .completed,
                fileSize: recordTarget?.fileSize ?? 0,
                fileCount: produced.count
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isProcessing = false
    }
}
