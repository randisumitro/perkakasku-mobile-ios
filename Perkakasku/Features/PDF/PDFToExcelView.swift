// xcode: set sdk=iOS

import SwiftUI
import UniformTypeIdentifiers

/// Server-backed PDF table extractor producing real `.xlsx` spreadsheets via `/api/tools/pdf-to-excel`.
struct PDFToExcelView: View {
    let tool: Tool

    @EnvironmentObject private var apiService: APIService
    @EnvironmentObject private var pdfService: PDFService
    @EnvironmentObject private var history: HistoryService

    @State private var selectedURL: URL?
    @State private var pageCount: Int = 0
    @State private var pageRangeText: String = ""
    @State private var sheetName: String = "Extracted Data"

    @State private var isProcessing = false
    @State private var outputURL: URL?
    @State private var tableCount: Int = 0
    @State private var extractedPages: Int = 0
    @State private var previewText: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileImportButton(
                title: selectedURL == nil ? "Select PDF with Tables" : "Choose Another PDF",
                hint: "Extracts structured rows and columns into Excel (.xlsx)",
                icon: "tablecells.badge.ellipsis",
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
                errorMessage = nil
                PKHaptics.selection()
            }

            if let selectedURL {
                ToolSettingsCard(
                    title: "Extraction Options",
                    badge: pageCount > 0 ? "\(pageCount) pages" : nil
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ToolFileItemRow(
                            fileName: selectedURL.displayName,
                            meta: "\(selectedURL.formattedSize) · \(pageCount) pages",
                            icon: "doc.fill"
                        ) {
                            self.selectedURL = nil
                            outputURL = nil
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Worksheet Name")
                                .font(PKFont.body(.caption, weight: .semibold))
                                .foregroundStyle(PKColors.textSecondary)
                            TextField("Extracted Data", text: $sheetName)
                                .font(PKFont.body(.subheadline))
                                .padding(10)
                                .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Page Filter (optional, e.g. 1-3, 5)")
                                .font(PKFont.body(.caption, weight: .semibold))
                                .foregroundStyle(PKColors.textSecondary)
                            TextField("Leave blank for all pages", text: $pageRangeText)
                                .font(PKFont.mono(.subheadline, weight: .regular))
                                .padding(10)
                                .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                        }

                        PrimaryButton(
                            title: "Extract to Excel (.xlsx)",
                            icon: "tablecells",
                            isLoading: isProcessing
                        ) {
                            Task { await convertToExcel() }
                        }
                    }
                }
            }

            if isProcessing {
                LoadingView(message: "Detecting tabular coordinates & building .xlsx…")
            }

            if let errorMessage {
                ErrorView(
                    message: errorMessage,
                    onRetry: { Task { await convertToExcel() } },
                    onDismiss: { self.errorMessage = nil }
                )
            }

            if let outputURL {
                ToolResultCard(
                    title: "Excel Workbook Ready",
                    subtitle: "Open QuickLook Preview to inspect cells or export directly.",
                    fileURL: outputURL,
                    originalBytes: selectedURL?.fileSize,
                    outputBytes: outputURL.fileSize,
                    metrics: [
                        ("Detected Rows/Tables", "\(max(1, tableCount))"),
                        ("Pages Processed", "\(max(1, extractedPages))"),
                    ],
                    exportLabel: "Export Excel (.xlsx)"
                )

                if let previewText, !previewText.isEmpty {
                    ToolSettingsCard(title: "Extracted Preview") {
                        Text(previewText)
                            .font(PKFont.mono(.caption, weight: .regular))
                            .foregroundStyle(PKColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func convertToExcel() async {
        guard let url = selectedURL else { return }
        isProcessing = true
        errorMessage = nil
        outputURL = nil

        let trimmedPages = pageRangeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSheet = sheetName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let multipart = try FileService.shared.multipartFile(
                from: url,
                fieldName: "file",
                maxFileSizeMB: tool.maxFileSizeMB
            )
            let decoded = try await apiService.pdfToExcel(
                file: multipart,
                pages: trimmedPages.isEmpty ? nil : trimmedPages,
                sheetName: trimmedSheet.isEmpty ? "Sheet1" : trimmedSheet
            )

            let outName = FileUtils.outputFileName(input: url.lastPathComponent, suffix: "", ext: "xlsx")
            let dest = LocalFileManager.shared.documentsURL(for: outName)
            try LocalFileManager.shared.write(data: decoded.data, to: dest)

            outputURL = dest
            tableCount = decoded.metadata.tableCount ?? 0
            extractedPages = decoded.metadata.extractedPages ?? pageCount
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
