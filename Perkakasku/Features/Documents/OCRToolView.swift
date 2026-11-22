// xcode: set sdk=iOS

import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// On-device Apple Vision OCR recognizer supporting photos, image files, and multi-page PDFs.
struct OCRToolView: View {
    private enum SourceInput {
        case image(UIImage, name: String)
        case pdf(URL, pageCount: Int)
    }

    let tool: Tool

    @EnvironmentObject private var imageService: ImageService
    @EnvironmentObject private var pdfService: PDFService
    @EnvironmentObject private var history: HistoryService

    @State private var source: SourceInput?
    @State private var language: OCRLanguageOption = .indonesianAndEnglish
    @State private var enhanceContrast: Bool = true

    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var progressMessage: String = "Recognizing text with Apple Vision…"

    @State private var extractedText: String = ""
    @State private var resultMeta: OCRResult?
    @State private var outputURL: URL?
    @State private var copied = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                PhotoImportButton(
                    title: source == nil ? "Pick Photo / Scan from Library" : "Choose Another Photo",
                    maxSelectionCount: 1,
                    compact: source != nil
                ) { imgs in
                    guard let img = imgs.first else { return }
                    source = .image(imageService.normalizedOrientation(img), name: "scan_\(Int(Date().timeIntervalSince1970)).png")
                    resetResult()
                }

                FileImportButton(
                    title: "Or Import PDF / Image File",
                    hint: "Supports scanned PDFs (up to 40 pages), JPG, PNG, HEIC",
                    icon: "doc.viewfinder.fill",
                    allowedUTIs: [UTType.pdf.identifier] + FileUtils.imageUTIs,
                    allowsMultiple: false,
                    compact: true,
                    onError: { errorMessage = $0 }
                ) { urls in
                    guard let url = urls.first else { return }
                    if url.pathExtension.lowercased() == "pdf" {
                        let count = pdfService.pageCount(url: url)
                        source = .pdf(url, pageCount: count)
                    } else if let data = try? LocalFileManager.shared.read(from: url),
                              let img = UIImage(data: data) {
                        source = .image(imageService.normalizedOrientation(img), name: url.lastPathComponent)
                    } else {
                        errorMessage = "Could not load the selected document."
                        return
                    }
                    resetResult()
                }
            }

            if let source {
                ToolSettingsCard(title: "Recognition Controls", badge: sourceBadge(source)) {
                    VStack(alignment: .leading, spacing: 12) {
                        switch source {
                        case .image(let img, let name):
                            HStack(spacing: 12) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 72, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(PKColors.border, lineWidth: 1))

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(name)
                                        .font(PKFont.body(.subheadline, weight: .semibold))
                                        .lineLimit(1)
                                    Button {
                                        let rotated = imageService.rotate90(img)
                                        self.source = .image(rotated, name: name)
                                        PKHaptics.selection()
                                    } label: {
                                        Label("Rotate 90°", systemImage: "rotate.right")
                                    }
                                    .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))
                                }
                            }

                        case .pdf(let url, let count):
                            ToolFileItemRow(
                                fileName: url.displayName,
                                meta: "\(url.formattedSize) · \(count) page\(count == 1 ? "" : "s")",
                                icon: "doc.fill"
                            )
                        }

                        Picker("Recognition Language", selection: $language) {
                            ForEach(OCRLanguageOption.allCases) { opt in
                                Text(opt.displayName).tag(opt)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Enhance document contrast before OCR", isOn: $enhanceContrast)
                            .font(PKFont.body(.subheadline))

                        PrimaryButton(
                            title: "Extract Text (OCR)",
                            icon: "text.viewfinder",
                            isLoading: isProcessing
                        ) {
                            Task { await runOCR() }
                        }
                    }
                }
            }

            if isProcessing {
                LoadingView(message: progressMessage, progress: progress > 0 ? progress : nil)
            }

            if let errorMessage {
                ErrorView(
                    message: errorMessage,
                    onRetry: source != nil ? { Task { await runOCR() } } : nil,
                    onDismiss: { self.errorMessage = nil }
                )
            }

            if let resultMeta {
                ToolSettingsCard(
                    title: "Extracted Text",
                    subtitle: "\(resultMeta.pageCount) page(s) · Confidence ~\(resultMeta.averageConfidence)%",
                    badge: "\(extractedText.wordCount) words"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        TextEditor(text: $extractedText)
                            .font(PKFont.body(.subheadline))
                            .frame(minHeight: 200)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(PKColors.border, lineWidth: 1))

                        HStack(spacing: 10) {
                            Button {
                                UIPasteboard.general.string = extractedText
                                copied = true
                                PKHaptics.success()
                            } label: {
                                Label(copied ? "Copied" : "Copy Text", systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))

                            if let outputURL {
                                ShareLink(item: outputURL) {
                                    Label("Share .TXT", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PKPillButtonStyle(variant: .primary, compact: true))
                            }
                        }
                    }
                }
            }
        }
    }

    private func sourceBadge(_ source: SourceInput) -> String {
        switch source {
        case .image: return "Image"
        case .pdf(_, let count): return "\(count)p PDF"
        }
    }

    private func resetResult() {
        resultMeta = nil
        extractedText = ""
        outputURL = nil
        errorMessage = nil
        copied = false
        PKHaptics.selection()
    }

    private func runOCR() async {
        guard let source else { return }
        isProcessing = true
        progress = 0
        progressMessage = "Recognizing text with Apple Vision…"
        errorMessage = nil
        copied = false

        do {
            let result: OCRResult
            let inputLabel: String

            switch source {
            case .image(let img, let name):
                inputLabel = name
                result = try await VisionOCRService.shared.recognizeImage(
                    img,
                    language: language,
                    enhanceContrast: enhanceContrast
                )

            case .pdf(let url, _):
                inputLabel = url.lastPathComponent
                result = try await VisionOCRService.shared.recognizePDF(
                    url: url,
                    language: language,
                    enhanceContrast: enhanceContrast
                ) { frac, status in
                    Task { @MainActor in
                        progress = frac
                        progressMessage = status
                    }
                }
            }

            extractedText = result.text
            resultMeta = result

            let outName = FileUtils.outputFileName(input: inputLabel, suffix: "_ocr", ext: "txt")
            let dest = LocalFileManager.shared.documentsURL(for: outName)
            if let data = result.text.data(using: .utf8) {
                try LocalFileManager.shared.write(data: data, to: dest)
                outputURL = dest
                history.record(
                    tool: tool,
                    inputFileName: inputLabel,
                    outputFileName: dest.lastPathComponent,
                    outputURL: dest,
                    status: .completed,
                    fileSize: Int64(data.count)
                )
            }
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isProcessing = false
    }
}
