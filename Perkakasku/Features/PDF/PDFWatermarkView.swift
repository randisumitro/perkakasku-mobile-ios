// xcode: set sdk=iOS

import SwiftUI
import UniformTypeIdentifiers

/// Local CoreGraphics vector PDF watermarker supporting text & image stamps.
struct PDFWatermarkView: View {
    enum WatermarkType: String, CaseIterable, Identifiable {
        case text = "Text"
        case image = "Logo Stamp"

        var id: String { rawValue }
    }

    let tool: Tool

    @EnvironmentObject private var pdfService: PDFService
    @EnvironmentObject private var history: HistoryService

    @State private var selectedURL: URL?
    @State private var pageCount: Int = 0
    @State private var previewThumb: UIImage?

    @State private var watermarkType: WatermarkType = .text
    @State private var watermarkText: String = "CONFIDENTIAL"
    @State private var stampImage: UIImage?
    @State private var textColor: Color = Color(red: 0.85, green: 0.27, blue: 0.03)
    @State private var position: PDFWatermarkPosition = .center
    @State private var opacity: Double = 0.28
    @State private var rotationDegrees: Double = -32
    @State private var fontSizeRatio: Double = 0.08
    @State private var pageRangeSpec: String = ""

    @State private var isProcessing = false
    @State private var outputURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileImportButton(
                title: selectedURL == nil ? "Select PDF to Watermark" : "Choose Another PDF",
                hint: "Stamp text or logo marks across every or selected pages",
                icon: "drop.fill",
                allowedUTIs: [UTType.pdf.identifier],
                allowsMultiple: false,
                compact: selectedURL != nil,
                onError: { errorMessage = $0 }
            ) { urls in
                guard let url = urls.first else { return }
                selectedURL = url
                pageCount = pdfService.pageCount(url: url)
                previewThumb = pdfService.renderThumbnail(url: url, pageIndex: 0, maxDimension: 360)
                outputURL = nil
                errorMessage = nil
                PKHaptics.selection()
            }

            if let selectedURL {
                ToolSettingsCard(
                    title: "Watermark Controls",
                    badge: pageCount > 0 ? "\(pageCount) pages" : nil
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        ToolFileItemRow(
                            fileName: selectedURL.displayName,
                            meta: "\(selectedURL.formattedSize) · \(pageCount) pages",
                            icon: "doc.fill"
                        ) {
                            self.selectedURL = nil
                            outputURL = nil
                        }

                        if let previewThumb {
                            ZStack {
                                Image(uiImage: previewThumb)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(PKColors.border, lineWidth: 1))

                                Group {
                                    if watermarkType == .text {
                                        Text(watermarkText.isEmpty ? "WATERMARK" : watermarkText)
                                            .font(.system(size: max(12, 220 * fontSizeRatio), weight: .bold))
                                            .foregroundStyle(textColor.opacity(opacity))
                                            .rotationEffect(.degrees(rotationDegrees))
                                    } else if let stampImage {
                                        Image(uiImage: stampImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 72, height: 72)
                                            .opacity(opacity)
                                            .rotationEffect(.degrees(rotationDegrees))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }

                        Picker("Type", selection: $watermarkType) {
                            ForEach(WatermarkType.allCases) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)

                        if watermarkType == .text {
                            TextField("Watermark text (e.g. CONFIDENTIAL)", text: $watermarkText)
                                .font(PKFont.body(.subheadline, weight: .semibold))
                                .padding(10)
                                .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))

                            ColorPicker("Text Color", selection: $textColor, supportsOpacity: false)
                                .font(PKFont.body(.subheadline))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Scale: \(Int(fontSizeRatio * 100))% of page")
                                    .font(PKFont.mono(.caption, weight: .medium))
                                Slider(value: $fontSizeRatio, in: 0.04...0.16)
                            }
                        } else {
                            PhotoImportButton(
                                title: stampImage == nil ? "Pick Stamp Logo from Photos" : "Replace Stamp Logo",
                                maxSelectionCount: 1,
                                compact: true
                            ) { imgs in
                                stampImage = imgs.first
                            }
                        }

                        Picker("Position", selection: $position) {
                            ForEach(PDFWatermarkPosition.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.menu)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Opacity: \(Int(opacity * 100))%")
                                .font(PKFont.mono(.caption, weight: .medium))
                            Slider(value: $opacity, in: 0.08...0.9)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rotation: \(Int(rotationDegrees))°")
                                .font(PKFont.mono(.caption, weight: .medium))
                            Slider(value: $rotationDegrees, in: -60...60, step: 1)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Page Range (optional, leave empty for all pages)")
                                .font(PKFont.body(.caption, weight: .semibold))
                                .foregroundStyle(PKColors.textSecondary)
                            TextField("e.g. 1-3, 5", text: $pageRangeSpec)
                                .font(PKFont.mono(.subheadline, weight: .regular))
                                .padding(10)
                                .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))
                        }

                        PrimaryButton(
                            title: "Apply Watermark",
                            icon: "drop.fill",
                            isLoading: isProcessing
                        ) {
                            applyWatermark()
                        }
                    }
                }
            }

            if isProcessing {
                LoadingView(message: "Stamping watermark onto pages…")
            }

            if let errorMessage {
                ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }

            if let outputURL {
                VStack(alignment: .leading, spacing: 14) {
                    ToolResultCard(
                        title: "Watermark Applied",
                        subtitle: "Vector PDF stamped locally without quality loss.",
                        fileURL: outputURL,
                        originalBytes: selectedURL?.fileSize,
                        outputBytes: outputURL.fileSize,
                        metrics: [
                            ("Position", position.rawValue),
                            ("Opacity", "\(Int(opacity * 100))%"),
                        ],
                        exportLabel: "Export Watermarked PDF"
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

    private func applyWatermark() {
        guard let url = selectedURL else { return }
        let content: PDFWatermarkOptions.Content
        switch watermarkType {
        case .text:
            let clean = watermarkText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else {
                errorMessage = "Please enter watermark text."
                PKHaptics.error()
                return
            }
            content = .text(clean, color: UIColor(textColor), fontSizeRatio: fontSizeRatio)
        case .image:
            guard let stampImage else {
                errorMessage = "Please choose a stamp logo image."
                PKHaptics.error()
                return
            }
            content = .image(stampImage)
        }

        let trimmedPages = pageRangeSpec.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedPages: [Int]?
        if trimmedPages.isEmpty {
            parsedPages = nil
        } else {
            let pages = pdfService.parsePageRanges(trimmedPages, maxPage: pageCount)
            guard !pages.isEmpty else {
                errorMessage = PDFServiceError.invalidPageSelection.localizedDescription
                PKHaptics.error()
                return
            }
            parsedPages = pages
        }

        isProcessing = true
        errorMessage = nil
        outputURL = nil

        let options = PDFWatermarkOptions(
            content: content,
            position: position,
            opacity: opacity,
            rotationDegrees: rotationDegrees,
            pageNumbers: parsedPages
        )
        let outName = FileUtils.outputFileName(input: url.lastPathComponent, suffix: "_watermarked", ext: "pdf")

        do {
            let result = try pdfService.watermark(url: url, options: options, outputName: outName)
            outputURL = result
            history.record(
                tool: tool,
                inputFileName: url.lastPathComponent,
                outputFileName: result.lastPathComponent,
                outputURL: result,
                status: .completed,
                fileSize: result.fileSize
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isProcessing = false
    }
}
