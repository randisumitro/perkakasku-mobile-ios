// xcode: set sdk=iOS

import SwiftUI
import UniformTypeIdentifiers

/// Server + local fallback PDF compressor backed by `/api/tools/pdf-compress` and `PDFService.compressLocally`.
struct PDFCompressView: View {
    enum CompressionLevel: String, CaseIterable, Identifiable {
        case low
        case balanced
        case high

        var id: String { rawValue }

        var title: String {
            switch self {
            case .low: return "Light Compression"
            case .balanced: return "Balanced (Recommended)"
            case .high: return "Maximum Reduction"
            }
        }

        var subtitle: String {
            switch self {
            case .low: return "Keeps maximum clarity for archival & print."
            case .balanced: return "Best trade-off between sharp pages and compact size."
            case .high: return "Aggressive reduction for strict upload limits."
            }
        }
    }

    let tool: Tool

    @EnvironmentObject private var history: HistoryService
    @EnvironmentObject private var pdfService: PDFService
    @EnvironmentObject private var apiService: APIService

    @State private var selectedURL: URL?
    @State private var pageCount: Int = 0
    @State private var thumbnail: UIImage?
    @State private var level: CompressionLevel = .balanced

    @State private var isProcessing = false
    @State private var outputURL: URL?
    @State private var originalBytes: Int64 = 0
    @State private var outputBytes: Int64 = 0
    @State private var engineUsed: String = ""
    @State private var alreadyOptimal: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileImportButton(
                title: selectedURL == nil ? "Select PDF File" : "Choose Another PDF",
                hint: "Up to \(tool.maxFileSizeMB ?? 50) MB · Single PDF document",
                icon: "arrow.down.doc.fill",
                allowedUTIs: [UTType.pdf.identifier],
                allowsMultiple: false,
                compact: selectedURL != nil,
                onError: { errorMessage = $0 }
            ) { urls in
                guard let url = urls.first else { return }
                loadSelectedPDF(url)
            }

            if let selectedURL {
                ToolSettingsCard(
                    title: "Selected Document",
                    badge: pageCount > 0 ? "\(pageCount) pages" : nil
                ) {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            if let thumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 56, height: 72)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(PKColors.border, lineWidth: 1)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedURL.displayName)
                                    .font(PKFont.body(.subheadline, weight: .semibold))
                                    .foregroundStyle(PKColors.textPrimary)
                                    .lineLimit(2)
                                Text("Original size: \(selectedURL.formattedSize)")
                                    .font(PKFont.mono(.caption2, weight: .medium))
                                    .foregroundStyle(PKColors.textMuted)
                            }
                            Spacer(minLength: 0)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Compression Profile")
                                .font(PKFont.body(.caption, weight: .bold))
                                .foregroundStyle(PKColors.textSecondary)

                            ForEach(CompressionLevel.allCases) { option in
                                ToolOptionCard(
                                    title: option.title,
                                    subtitle: option.subtitle,
                                    isSelected: level == option
                                ) {
                                    level = option
                                }
                            }
                        }

                        PrimaryButton(
                            title: "Compress PDF",
                            icon: "arrow.down.right.and.arrow.up.left",
                            isLoading: isProcessing
                        ) {
                            Task { await compressOnServer() }
                        }
                    }
                }
            }

            if isProcessing {
                LoadingView(message: "Compressing PDF in sandbox…")
            }

            if let errorMessage {
                VStack(spacing: 10) {
                    ErrorView(
                        message: errorMessage,
                        onRetry: { Task { await compressOnServer() } },
                        onDismiss: { self.errorMessage = nil }
                    )

                    if selectedURL != nil {
                        Button {
                            compressLocallyFallback()
                        } label: {
                            Label("Run On-Device Fallback Optimization", systemImage: "cpu.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PKPillButtonStyle(variant: .ink, compact: true))
                    }
                }
            }

            if let outputURL {
                VStack(alignment: .leading, spacing: 14) {
                    ToolResultCard(
                        title: alreadyOptimal ? "PDF Already Compact" : "PDF Compressed",
                        subtitle: alreadyOptimal
                            ? "Re-serialized cleanly; original structure was already near minimum size."
                            : "Ready to preview or export.",
                        fileURL: outputURL,
                        originalBytes: originalBytes,
                        outputBytes: outputBytes,
                        metrics: [
                            ("Pages", "\(max(1, pageCount))"),
                            ("Engine", engineUsed.isEmpty ? "Server" : engineUsed),
                        ],
                        exportLabel: "Export Compressed PDF",
                        onReset: { resetTool() }
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

    private func loadSelectedPDF(_ url: URL) {
        selectedURL = url
        outputURL = nil
        errorMessage = nil
        originalBytes = url.fileSize
        pageCount = pdfService.pageCount(url: url)
        thumbnail = pdfService.renderThumbnail(url: url, pageIndex: 0, maxDimension: 240)
        PKHaptics.selection()
    }

    private func compressOnServer() async {
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
            let decoded = try await apiService.compressPDF(file: multipart, level: level.rawValue)
            let outName = FileUtils.outputFileName(input: url.lastPathComponent, suffix: "_compressed", ext: "pdf")
            let dest = LocalFileManager.shared.documentsURL(for: outName)
            try LocalFileManager.shared.write(data: decoded.data, to: dest)

            outputURL = dest
            originalBytes = decoded.metadata.originalBytes ?? url.fileSize
            outputBytes = Int64(decoded.data.count)
            engineUsed = decoded.metadata.engine ?? "Perkakasku Sandbox"
            alreadyOptimal = decoded.metadata.alreadyOptimal ?? false
            if let serverPages = decoded.metadata.pageCount, serverPages > 0 {
                pageCount = serverPages
            }

            history.record(
                tool: tool,
                inputFileName: url.lastPathComponent,
                outputFileName: dest.lastPathComponent,
                outputURL: dest,
                status: .completed,
                fileSize: outputBytes
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

    private func compressLocallyFallback() {
        guard let url = selectedURL else { return }
        isProcessing = true
        errorMessage = nil

        do {
            let outName = FileUtils.outputFileName(input: url.lastPathComponent, suffix: "_optimized", ext: "pdf")
            let (dest, pages) = try pdfService.compressLocally(url: url, outputName: outName)
            outputURL = dest
            originalBytes = url.fileSize
            outputBytes = dest.fileSize
            pageCount = pages
            engineUsed = "On-Device PDFKit"
            alreadyOptimal = outputBytes >= originalBytes

            history.record(
                tool: tool,
                inputFileName: url.lastPathComponent,
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

    private func resetTool() {
        selectedURL = nil
        outputURL = nil
        thumbnail = nil
        errorMessage = nil
        pageCount = 0
    }
}
