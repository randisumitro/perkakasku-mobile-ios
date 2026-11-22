// xcode: set sdk=iOS

import SwiftUI
import UniformTypeIdentifiers

/// High-DPI local PDF-to-Image renderer supporting PNG/JPG, 72/150/300 DPI, page filtering & ZIP bundle.
struct PDFToImageView: View {
    enum PageScope: String, CaseIterable, Identifiable {
        case all = "All Pages"
        case custom = "Custom Range"

        var id: String { rawValue }
    }

    let tool: Tool

    @EnvironmentObject private var pdfService: PDFService
    @EnvironmentObject private var imageService: ImageService
    @EnvironmentObject private var history: HistoryService

    @State private var selectedURL: URL?
    @State private var totalPages: Int = 0
    @State private var format: PDFImageFormat = .png
    @State private var dpi: CGFloat = 150
    @State private var pageScope: PageScope = .all
    @State private var rangeSpec: String = ""

    @State private var renderedImages: [UIImage] = []
    @State private var exportedImageURLs: [URL] = []
    @State private var zipURL: URL?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileImportButton(
                title: selectedURL == nil ? "Select PDF to Convert" : "Choose Another PDF",
                hint: "Render every page to crisp PNG or JPG on your device",
                icon: "photo.on.rectangle.angled",
                allowedUTIs: [UTType.pdf.identifier],
                allowsMultiple: false,
                compact: selectedURL != nil,
                onError: { errorMessage = $0 }
            ) { urls in
                guard let url = urls.first else { return }
                selectedURL = url
                totalPages = pdfService.pageCount(url: url)
                rangeSpec = totalPages > 1 ? "1-\(min(totalPages, 5))" : "1"
                renderedImages = []
                exportedImageURLs = []
                zipURL = nil
                errorMessage = nil
                PKHaptics.selection()
            }

            if let selectedURL {
                ToolSettingsCard(
                    title: "Render Settings",
                    badge: "\(totalPages) page\(totalPages == 1 ? "" : "s")"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ToolFileItemRow(
                            fileName: selectedURL.displayName,
                            meta: "\(selectedURL.formattedSize) · \(totalPages) pages",
                            icon: "doc.fill"
                        ) {
                            self.selectedURL = nil
                            renderedImages = []
                            exportedImageURLs = []
                            zipURL = nil
                        }

                        Picker("Output Format", selection: $format) {
                            ForEach(PDFImageFormat.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Render Resolution (DPI)")
                                .font(PKFont.body(.caption, weight: .semibold))
                                .foregroundStyle(PKColors.textSecondary)

                            Picker("DPI", selection: $dpi) {
                                Text("72 DPI (Screen)").tag(CGFloat(72))
                                Text("150 DPI (Standard)").tag(CGFloat(150))
                                Text("300 DPI (Print)").tag(CGFloat(300))
                            }
                            .pickerStyle(.segmented)
                        }

                        Picker("Pages", selection: $pageScope) {
                            ForEach(PageScope.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)

                        if pageScope == .custom {
                            TextField("e.g. 1-3, 5", text: $rangeSpec)
                                .font(PKFont.mono(.subheadline, weight: .medium))
                                .padding(10)
                                .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                        }

                        PrimaryButton(
                            title: "Render PDF Pages",
                            icon: "photo.stack.fill",
                            isLoading: isProcessing
                        ) {
                            renderPages()
                        }
                    }
                }
            }

            if isProcessing {
                LoadingView(message: "Rendering high-DPI page images…")
            }

            if let errorMessage {
                ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }

            if !exportedImageURLs.isEmpty {
                let mainExport = zipURL ?? exportedImageURLs.first
                ToolResultCard(
                    title: "Pages Rendered",
                    subtitle: exportedImageURLs.count > 1
                        ? "All \(exportedImageURLs.count) images packed into a ZIP archive."
                        : "Single page rendered to \(format.rawValue).",
                    fileURL: mainExport,
                    outputBytes: mainExport?.fileSize,
                    metrics: [
                        ("Images", "\(exportedImageURLs.count)"),
                        ("Resolution", "\(Int(dpi)) DPI · \(format.rawValue)"),
                    ],
                    exportLabel: exportedImageURLs.count > 1 ? "Export All (.ZIP)" : "Export \(format.rawValue)",
                    imageToSave: renderedImages.count == 1 ? renderedImages.first : nil
                )

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(Array(zip(renderedImages, exportedImageURLs).enumerated()), id: \.offset) { idx, pair in
                        let (img, fileURL) = pair
                        VStack(spacing: 8) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(PKColors.border, lineWidth: 1)
                                )

                            HStack {
                                Text("Page \(idx + 1)")
                                    .font(PKFont.mono(.caption2, weight: .bold))
                                    .foregroundStyle(PKColors.textSecondary)
                                Spacer()
                                ShareLink(item: fileURL) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(PKColors.brand)
                                }
                            }
                        }
                        .pkCard(radius: PKRadius.sm, background: PKColors.surface, border: PKColors.border, padding: 10)
                    }
                }
            }
        }
    }

    private func renderPages() {
        guard let url = selectedURL else { return }
        isProcessing = true
        errorMessage = nil
        renderedImages = []
        exportedImageURLs = []
        zipURL = nil

        let targetPages: [Int]?
        if pageScope == .custom {
            let parsed = pdfService.parsePageRanges(rangeSpec, maxPage: totalPages)
            guard !parsed.isEmpty else {
                errorMessage = PDFServiceError.invalidPageSelection.localizedDescription
                isProcessing = false
                PKHaptics.error()
                return
            }
            targetPages = parsed
        } else {
            targetPages = nil
        }

        let imgs = pdfService.pdfToImages(url: url, dpi: dpi, pages: targetPages)
        guard !imgs.isEmpty else {
            errorMessage = PDFServiceError.invalidPDF.localizedDescription
            isProcessing = false
            PKHaptics.error()
            return
        }

        do {
            let base = url.deletingPathExtension().lastPathComponent
            var urls: [URL] = []
            var entries: [ZIPBuilder.Entry] = []
            let imgFormat: ImageService.Format = format == .png ? .png : .jpeg(quality: 0.92)

            for (idx, img) in imgs.enumerated() {
                guard let encoded = imageService.convert(image: img, to: imgFormat) else { continue }
                let pageNum = targetPages?[safe: idx] ?? (idx + 1)
                let fileName = "\(base)_p\(String(format: "%03d", pageNum)).\(format.fileExtension)"
                let dest = LocalFileManager.shared.documentsURL(for: fileName)
                try LocalFileManager.shared.write(data: encoded, to: dest)
                urls.append(dest)
                entries.append(ZIPBuilder.Entry(fileName: fileName, data: encoded))
            }

            renderedImages = imgs
            exportedImageURLs = urls
            if entries.count > 1 {
                let zipData = try ZIPBuilder.buildArchive(entries: entries)
                let zURL = LocalFileManager.shared.documentsURL(for: "\(base)_images.zip")
                try LocalFileManager.shared.write(data: zipData, to: zURL)
                zipURL = zURL
            }

            let recordTarget = zipURL ?? exportedImageURLs.first
            history.record(
                tool: tool,
                inputFileName: url.lastPathComponent,
                outputFileName: recordTarget?.lastPathComponent,
                outputURL: recordTarget,
                status: .completed,
                fileSize: recordTarget?.fileSize ?? 0,
                fileCount: urls.count
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isProcessing = false
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
