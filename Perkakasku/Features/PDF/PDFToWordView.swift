// xcode: set sdk=iOS

import SwiftUI
import UniformTypeIdentifiers

/// Server-backed PDF to Microsoft Word (.docx) converter via `/api/tools/pdf-to-word`.
struct PDFToWordView: View {
    let tool: Tool

    @EnvironmentObject private var apiService: APIService
    @EnvironmentObject private var pdfService: PDFService
    @EnvironmentObject private var history: HistoryService
    @EnvironmentObject private var registry: ToolRegistryService

    @State private var selectedURL: URL?
    @State private var pageCount: Int = 0
    @State private var isProcessing = false
    @State private var outputURL: URL?
    @State private var convertedPages: Int = 0
    @State private var extractedChars: Int = 0
    @State private var isScannedPdf: Bool = false
    @State private var previewText: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileImportButton(
                title: selectedURL == nil ? "Select PDF to Convert" : "Choose Another PDF",
                hint: "Extracts paragraphs & layout into editable Word (.docx)",
                icon: "doc.text.fill",
                allowedUTIs: [UTType.pdf.identifier],
                allowsMultiple: false,
                compact: selectedURL != nil,
                onError: { errorMessage = $0 }
            ) { urls in
                guard let url = urls.first else { return }
                selectedURL = url
                pageCount = pdfService.pageCount(url: url)
                outputURL = nil
                previewText = nil
                isScannedPdf = false
                errorMessage = nil
                PKHaptics.selection()
            }

            if let selectedURL {
                ToolSettingsCard(
                    title: "Ready to Convert",
                    badge: pageCount > 0 ? "\(pageCount) pages" : nil
                ) {
                    VStack(spacing: 12) {
                        ToolFileItemRow(
                            fileName: selectedURL.displayName,
                            meta: "\(selectedURL.formattedSize) · \(pageCount) pages",
                            icon: "doc.fill"
                        ) {
                            self.selectedURL = nil
                            outputURL = nil
                        }

                        PrimaryButton(
                            title: "Convert PDF to Word (.docx)",
                            icon: "arrow.right.doc.on.clipboard",
                            isLoading: isProcessing
                        ) {
                            Task { await convertToWord() }
                        }
                    }
                }
            }

            if isProcessing {
                LoadingView(message: "Converting PDF structure to Word (.docx)…")
            }

            if let errorMessage {
                ErrorView(
                    message: errorMessage,
                    onRetry: { Task { await convertToWord() } },
                    onDismiss: { self.errorMessage = nil }
                )
            }

            if isScannedPdf, let ocrTool = registry.tool(slug: "ocr") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Scanned PDF Detected", systemImage: "doc.text.viewfinder")
                        .font(PKFont.body(.subheadline, weight: .bold))
                        .foregroundStyle(PKColors.warning)
                    Text("This PDF appears to contain page images without embedded text. Run OCR Text Recognition offline to extract text from every page.")
                        .font(PKFont.body(.caption))
                        .foregroundStyle(PKColors.textSecondary)
                    NavigationLink(value: ocrTool) {
                        Label("Open OCR Text Recognition", systemImage: "arrow.right")
                            .font(PKFont.body(.caption, weight: .bold))
                    }
                    .buttonStyle(PKPillButtonStyle(variant: .ink, compact: true))
                }
                .padding(14)
                .background(PKColors.warningSoft, in: RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous)
                        .strokeBorder(PKColors.warning.opacity(0.35), lineWidth: 1)
                )
            }

            if let outputURL {
                ToolResultCard(
                    title: "Word Document Ready",
                    subtitle: "Tap Preview to inspect in QuickLook or export to Pages / Word.",
                    fileURL: outputURL,
                    originalBytes: selectedURL?.fileSize,
                    outputBytes: outputURL.fileSize,
                    metrics: [
                        ("Converted Pages", "\(max(1, convertedPages))"),
                        ("Extracted Chars", "\(extractedChars)"),
                    ],
                    exportLabel: "Export Word (.docx)"
                )

                if let previewText, !previewText.isEmpty {
                    ToolSettingsCard(title: "Text Excerpt") {
                        Text(previewText)
                            .font(PKFont.body(.caption))
                            .foregroundStyle(PKColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func convertToWord() async {
        guard let url = selectedURL else { return }
        isProcessing = true
        errorMessage = nil
        outputURL = nil

        do {
            let multipart = try FileService.shared.multipartFile(
                from: url,
                fieldName: "file",
                maxFileSizeMB: tool.maxFileSizeMB
            )
            let decoded = try await apiService.pdfToWord(file: multipart)
            let outName = FileUtils.outputFileName(input: url.lastPathComponent, suffix: "", ext: "docx")
            let dest = LocalFileManager.shared.documentsURL(for: outName)
            try LocalFileManager.shared.write(data: decoded.data, to: dest)

            outputURL = dest
            convertedPages = decoded.metadata.convertedPages ?? pageCount
            extractedChars = decoded.metadata.extractedChars ?? 0
            isScannedPdf = decoded.metadata.isScannedPdf ?? false
            previewText = decoded.metadata.previewText

            history.record(
                tool: tool,
                inputFileName: url.lastPathComponent,
                outputFileName: dest.lastPathComponent,
                outputURL: dest,
                status: .completed,
                fileSize: Int64(decoded.data.count)
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            history.record(
                tool: tool,
                inputFileName: url.lastPathComponent,
                status: .failed,
                fileSize: url.fileSize
            )
            PKHaptics.error()
        }

        isProcessing = false
    }
}
