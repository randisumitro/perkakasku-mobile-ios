// xcode: set sdk=iOS

import SwiftUI
import UniformTypeIdentifiers

/// Local PDF splitter supporting all-page splitting, range extraction, and ZIP packaging.
struct PDFSplitView: View {
    enum SplitMode: String, CaseIterable, Identifiable {
        case allPages = "Split Every Page"
        case combinedRange = "Extract Range into 1 PDF"
        case splitRange = "Split Selected Pages"

        var id: String { rawValue }
    }

    let tool: Tool

    @EnvironmentObject private var pdfService: PDFService
    @EnvironmentObject private var history: HistoryService

    @State private var selectedURL: URL?
    @State private var pageCount: Int = 0
    @State private var splitMode: SplitMode = .allPages
    @State private var rangeSpec: String = ""

    @State private var splitURLs: [URL] = []
    @State private var archiveURL: URL?
    @State private var previewURL: URL?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileImportButton(
                title: selectedURL == nil ? "Select PDF to Split" : "Choose Another PDF",
                hint: "Extract individual pages or custom page ranges",
                icon: "scissors",
                allowedUTIs: [UTType.pdf.identifier],
                allowsMultiple: false,
                compact: selectedURL != nil,
                onError: { errorMessage = $0 }
            ) { urls in
                guard let url = urls.first else { return }
                selectedURL = url
                pageCount = pdfService.pageCount(url: url)
                rangeSpec = pageCount > 1 ? "1-\(min(pageCount, 3))" : "1"
                splitURLs = []
                archiveURL = nil
                errorMessage = nil
                PKHaptics.selection()
            }

            if let selectedURL {
                ToolSettingsCard(
                    title: "Split Options",
                    badge: "\(pageCount) page\(pageCount == 1 ? "" : "s")"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ToolFileItemRow(
                            fileName: selectedURL.displayName,
                            meta: "\(selectedURL.formattedSize) · \(pageCount) pages",
                            icon: "doc.fill"
                        ) {
                            self.selectedURL = nil
                            splitURLs = []
                            archiveURL = nil
                        }

                        ForEach(SplitMode.allCases) { mode in
                            ToolOptionCard(
                                title: mode.rawValue,
                                subtitle: modeSubtitle(mode),
                                isSelected: splitMode == mode
                            ) {
                                splitMode = mode
                            }
                        }

                        if splitMode != .allPages {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Page Range (e.g. 1-3, 5, 7-\(max(7, pageCount)))")
                                    .font(PKFont.body(.caption, weight: .semibold))
                                    .foregroundStyle(PKColors.textSecondary)
                                TextField("1-3, 5", text: $rangeSpec)
                                    .font(PKFont.mono(.subheadline, weight: .medium))
                                    .padding(10)
                                    .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        PrimaryButton(
                            title: splitMode == .combinedRange ? "Extract Selected PDF" : "Split PDF Pages",
                            icon: "scissors",
                            isLoading: isProcessing
                        ) {
                            runSplit()
                        }
                    }
                }
            }

            if isProcessing {
                LoadingView(message: "Splitting pages on device…")
            }

            if let errorMessage {
                ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }

            if let primaryExport = archiveURL ?? splitURLs.first {
                VStack(alignment: .leading, spacing: 14) {
                    ToolResultCard(
                        title: "Split Complete",
                        subtitle: splitURLs.count > 1
                            ? "Packaged \(splitURLs.count) pages as a ZIP archive, plus individual downloads below."
                            : "Extracted PDF is ready to preview or share.",
                        fileURL: primaryExport,
                        outputBytes: primaryExport.fileSize,
                        metrics: [
                            ("Output Files", "\(splitURLs.count)"),
                            ("Source Pages", "\(pageCount)"),
                        ],
                        exportLabel: splitURLs.count > 1 ? "Export All (.ZIP)" : "Export PDF"
                    )

                    if splitURLs.count > 1 {
                        ToolSettingsCard(title: "Individual Pages", badge: "\(splitURLs.count) files") {
                            VStack(spacing: 8) {
                                ForEach(splitURLs.prefix(30), id: \.self) { file in
                                    HStack(spacing: 10) {
                                        Image(systemName: "doc.fill")
                                            .foregroundStyle(PKColors.brand)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(file.lastPathComponent)
                                                .font(PKFont.mono(.caption, weight: .semibold))
                                                .foregroundStyle(PKColors.textPrimary)
                                            Text(file.formattedSize)
                                                .font(PKFont.mono(.caption2, weight: .regular))
                                                .foregroundStyle(PKColors.textMuted)
                                        }
                                        Spacer()

                                        Button {
                                            previewURL = file
                                        } label: {
                                            Image(systemName: "eye.fill")
                                                .padding(7)
                                                .background(PKColors.backgroundInset, in: Circle())
                                        }
                                        .buttonStyle(.plain)

                                        ShareLink(item: file) {
                                            Image(systemName: "square.and.arrow.up")
                                                .padding(7)
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
        .sheet(item: $previewURL) { url in
            QuickLookPreviewSheet(url: url, title: url.lastPathComponent)
        }
    }

    private func modeSubtitle(_ mode: SplitMode) -> String {
        switch mode {
        case .allPages: return "Create a separate PDF for every page and bundle as ZIP."
        case .combinedRange: return "Merge only your chosen pages into one clean PDF."
        case .splitRange: return "Create separate PDF files for each selected page."
        }
    }

    private func runSplit() {
        guard let url = selectedURL else { return }
        isProcessing = true
        errorMessage = nil
        splitURLs = []
        archiveURL = nil

        let base = url.deletingPathExtension().lastPathComponent
        do {
            switch splitMode {
            case .allPages:
                let outputs = try pdfService.split(url: url, pages: nil, outputPrefix: "\(base)_page")
                splitURLs = outputs
                if outputs.count > 1 {
                    archiveURL = try buildZip(from: outputs, zipName: "\(base)_split.zip")
                }

            case .combinedRange:
                let pages = pdfService.parsePageRanges(rangeSpec, maxPage: pageCount)
                guard !pages.isEmpty else {
                    throw PDFServiceError.invalidPageSelection
                }
                let out = try pdfService.extractCombinedRange(
                    url: url,
                    pages: pages,
                    outputName: "\(base)_extracted.pdf"
                )
                splitURLs = [out]

            case .splitRange:
                let pages = pdfService.parsePageRanges(rangeSpec, maxPage: pageCount)
                guard !pages.isEmpty else {
                    throw PDFServiceError.invalidPageSelection
                }
                let outputs = try pdfService.split(url: url, pages: pages, outputPrefix: "\(base)_page")
                splitURLs = outputs
                if outputs.count > 1 {
                    archiveURL = try buildZip(from: outputs, zipName: "\(base)_pages.zip")
                }
            }

            let recordURL = archiveURL ?? splitURLs.first
            history.record(
                tool: tool,
                inputFileName: url.lastPathComponent,
                outputFileName: recordURL?.lastPathComponent,
                outputURL: recordURL,
                status: .completed,
                fileSize: recordURL?.fileSize ?? 0,
                fileCount: splitURLs.count
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isProcessing = false
    }

    private func buildZip(from urls: [URL], zipName: String) throws -> URL {
        let entries = try urls.map { file -> ZIPBuilder.Entry in
            let data = try Data(contentsOf: file)
            return ZIPBuilder.Entry(fileName: file.lastPathComponent, data: data)
        }
        let zipData = try ZIPBuilder.buildArchive(entries: entries)
        let dest = LocalFileManager.shared.documentsURL(for: zipName)
        try LocalFileManager.shared.write(data: zipData, to: dest)
        return dest
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
