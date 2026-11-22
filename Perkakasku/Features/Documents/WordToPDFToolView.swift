// xcode: set sdk=iOS

import SwiftUI
import UniformTypeIdentifiers

/// Server-backed Microsoft Word (.docx) to PDF converter via `/api/tools/word-to-pdf`.
struct WordToPDFToolView: View {
    let tool: Tool

    @EnvironmentObject private var apiService: APIService
    @EnvironmentObject private var history: HistoryService

    @State private var selectedURL: URL?
    @State private var isProcessing = false
    @State private var outputURL: URL?
    @State private var previewText: String?
    @State private var errorMessage: String?

    private static var docxUTIs: [String] {
        var ids: [String] = []
        if let docx = UTType(filenameExtension: "docx") {
            ids.append(docx.identifier)
        }
        ids.append("org.openxmlformats.wordprocessingml.document")
        ids.append(UTType.data.identifier)
        return ids
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileImportButton(
                title: selectedURL == nil ? "Select Word File (.docx)" : "Choose Another .docx File",
                hint: "Supports modern Word (.docx) up to \(tool.maxFileSizeMB ?? 50) MB",
                icon: "doc.richtext",
                allowedUTIs: Self.docxUTIs,
                allowsMultiple: false,
                compact: selectedURL != nil,
                onError: { errorMessage = $0 }
            ) { urls in
                guard let url = urls.first else { return }
                selectedURL = url
                outputURL = nil
                previewText = nil
                errorMessage = nil
                PKHaptics.selection()
            }

            if let selectedURL {
                ToolSettingsCard(title: "Word Document Ready") {
                    VStack(spacing: 12) {
                        ToolFileItemRow(
                            fileName: selectedURL.displayName,
                            meta: selectedURL.formattedSize,
                            icon: "doc.text.fill"
                        ) {
                            self.selectedURL = nil
                            outputURL = nil
                        }

                        if selectedURL.pathExtension.lowercased() == "doc" {
                            Text("Legacy .doc files are unsupported without LibreOffice; please re-save as .docx before converting.")
                                .font(PKFont.body(.caption, weight: .semibold))
                                .foregroundStyle(PKColors.warning)
                        }

                        PrimaryButton(
                            title: "Convert to PDF",
                            icon: "arrow.right.doc.on.clipboard",
                            isLoading: isProcessing
                        ) {
                            Task { await convertWordToPDF() }
                        }
                    }
                }
            }

            if isProcessing {
                LoadingView(message: "Converting Word (.docx) to clean PDF in sandbox…")
            }

            if let errorMessage {
                ErrorView(
                    message: errorMessage,
                    onRetry: { Task { await convertWordToPDF() } },
                    onDismiss: { self.errorMessage = nil }
                )
            }

            if let outputURL {
                VStack(alignment: .leading, spacing: 14) {
                    ToolResultCard(
                        title: "PDF Ready",
                        subtitle: "Converted cleanly in Perkakasku sandbox.",
                        fileURL: outputURL,
                        originalBytes: selectedURL?.fileSize,
                        outputBytes: outputURL.fileSize,
                        metrics: [
                            ("Format", "PDF"),
                            ("Source", ".docx"),
                        ],
                        exportLabel: "Export PDF"
                    )

                    PDFKitPreviewView(url: outputURL)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous)
                                .strokeBorder(PKColors.border, lineWidth: 1)
                        )

                    if let previewText, !previewText.isEmpty {
                        ToolSettingsCard(title: "Document Excerpt") {
                            Text(previewText)
                                .font(PKFont.body(.caption))
                                .foregroundStyle(PKColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private func convertWordToPDF() async {
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
            let decoded = try await apiService.wordToPDF(file: multipart)
            let outName = FileUtils.outputFileName(input: url.lastPathComponent, suffix: "", ext: "pdf")
            let dest = LocalFileManager.shared.documentsURL(for: outName)
            try LocalFileManager.shared.write(data: decoded.data, to: dest)

            outputURL = dest
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
