// xcode: set sdk=iOS

import SwiftUI
import UniformTypeIdentifiers

/// Local PDF merger supporting multi-selection, manual reordering, and inline preview.
struct PDFMergeView: View {
    let tool: Tool

    @EnvironmentObject private var pdfService: PDFService
    @EnvironmentObject private var history: HistoryService

    @State private var selectedURLs: [URL] = []
    @State private var outputFileName: String = "merged_document"
    @State private var outputURL: URL?
    @State private var mergedPageCount: Int = 0
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private var totalSelectedPages: Int {
        selectedURLs.reduce(0) { $0 + pdfService.pageCount(url: $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileImportButton(
                title: selectedURLs.isEmpty ? "Add PDF Files to Merge" : "Add More PDFs",
                hint: "Select 2 or more PDF files from your device",
                icon: "doc.on.doc.fill",
                allowedUTIs: [UTType.pdf.identifier],
                allowsMultiple: true,
                compact: !selectedURLs.isEmpty,
                onError: { errorMessage = $0 }
            ) { urls in
                for url in urls where !selectedURLs.contains(url) {
                    selectedURLs.append(url)
                }
                outputURL = nil
                errorMessage = nil
                PKHaptics.selection()
            }

            if !selectedURLs.isEmpty {
                ToolSettingsCard(
                    title: "Document Order",
                    subtitle: "Use arrows to arrange merge sequence",
                    badge: "\(selectedURLs.count) files · \(totalSelectedPages) pages"
                ) {
                    VStack(spacing: 10) {
                        ForEach(Array(selectedURLs.enumerated()), id: \.element) { idx, url in
                            let pages = pdfService.pageCount(url: url)
                            HStack(spacing: 8) {
                                Text("\(idx + 1)")
                                    .font(PKFont.mono(.caption, weight: .bold))
                                    .foregroundStyle(PKColors.brand)
                                    .frame(width: 24, height: 24)
                                    .background(PKColors.brandSoft, in: Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(url.displayName)
                                        .font(PKFont.body(.subheadline, weight: .semibold))
                                        .foregroundStyle(PKColors.textPrimary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text("\(pages) page\(pages == 1 ? "" : "s") · \(url.formattedSize)")
                                        .font(PKFont.mono(.caption2, weight: .regular))
                                        .foregroundStyle(PKColors.textMuted)
                                }

                                Spacer(minLength: 4)

                                HStack(spacing: 4) {
                                    Button {
                                        moveItem(from: idx, by: -1)
                                    } label: {
                                        Image(systemName: "arrow.up")
                                            .font(.caption.weight(.bold))
                                            .frame(width: 28, height: 28)
                                            .background(PKColors.surface, in: Circle())
                                    }
                                    .disabled(idx == 0)

                                    Button {
                                        moveItem(from: idx, by: 1)
                                    } label: {
                                        Image(systemName: "arrow.down")
                                            .font(.caption.weight(.bold))
                                            .frame(width: 28, height: 28)
                                            .background(PKColors.surface, in: Circle())
                                    }
                                    .disabled(idx == selectedURLs.count - 1)

                                    Button {
                                        selectedURLs.remove(at: idx)
                                        outputURL = nil
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(PKColors.error)
                                            .frame(width: 28, height: 28)
                                            .background(PKColors.errorSoft, in: Circle())
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .pkInsetCard(radius: PKRadius.sm, padding: 10)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Output Filename")
                                .font(PKFont.body(.caption, weight: .semibold))
                                .foregroundStyle(PKColors.textSecondary)
                            TextField("merged_document", text: $outputFileName)
                                .font(PKFont.mono(.subheadline, weight: .medium))
                                .padding(10)
                                .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                        }

                        PrimaryButton(
                            title: selectedURLs.count < 2
                                ? "Select at least 2 PDFs"
                                : "Merge \(selectedURLs.count) PDFs (\(totalSelectedPages) pages)",
                            icon: "arrow.triangle.merge",
                            isLoading: isProcessing
                        ) {
                            mergePDFs()
                        }
                        .disabled(selectedURLs.count < 2)
                    }
                }
            }

            if isProcessing {
                LoadingView(message: "Combining PDF pages on device…")
            }

            if let errorMessage {
                ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }

            if let outputURL {
                VStack(alignment: .leading, spacing: 14) {
                    ToolResultCard(
                        title: "PDFs Merged",
                        subtitle: "Combined cleanly in exact sequence.",
                        fileURL: outputURL,
                        outputBytes: outputURL.fileSize,
                        metrics: [
                            ("Source Files", "\(selectedURLs.count)"),
                            ("Total Pages", "\(mergedPageCount)"),
                        ],
                        exportLabel: "Export Merged PDF",
                        onReset: {
                            selectedURLs = []
                            self.outputURL = nil
                            errorMessage = nil
                        }
                    )

                    PDFKitPreviewView(url: outputURL)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous)
                                .strokeBorder(PKColors.border, lineWidth: 1)
                        )
                }
            }
        }
    }

    private func moveItem(from index: Int, by offset: Int) {
        let target = index + offset
        guard selectedURLs.indices.contains(index), selectedURLs.indices.contains(target) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            selectedURLs.swapAt(index, target)
        }
        PKHaptics.selection()
    }

    private func mergePDFs() {
        guard selectedURLs.count >= 2 else { return }
        isProcessing = true
        errorMessage = nil
        outputURL = nil

        let cleanName = outputFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = cleanName.isEmpty ? "merged_document" : cleanName.replacingOccurrences(of: ".pdf", with: "")
        let fileName = "\(baseName).pdf"

        do {
            let merged = try pdfService.merge(urls: selectedURLs, outputName: fileName)
            outputURL = merged
            mergedPageCount = pdfService.pageCount(url: merged)

            history.record(
                tool: tool,
                inputFileName: "\(selectedURLs.count) PDFs",
                outputFileName: merged.lastPathComponent,
                outputURL: merged,
                status: .completed,
                fileSize: merged.fileSize,
                fileCount: selectedURLs.count
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isProcessing = false
    }
}
