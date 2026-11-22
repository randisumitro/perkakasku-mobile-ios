// xcode: set sdk=iOS

import SwiftUI
import UniformTypeIdentifiers

/// Combines multiple photos or image files into a single formatted PDF on-device.
struct ImageToPDFView: View {
    let tool: Tool

    @EnvironmentObject private var pdfService: PDFService
    @EnvironmentObject private var history: HistoryService

    @State private var images: [UIImage] = []
    @State private var pageSize: PDFPageSizeOption = .a4
    @State private var marginPoints: Double = 18
    @State private var outputName: String = "photos_document"

    @State private var isProcessing = false
    @State private var outputURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                PhotoImportButton(
                    title: images.isEmpty ? "Pick Photos from Library" : "Add More Photos",
                    maxSelectionCount: 20,
                    compact: !images.isEmpty
                ) { imported in
                    images.append(contentsOf: imported)
                    outputURL = nil
                    errorMessage = nil
                    PKHaptics.selection()
                }

                FileImportButton(
                    title: "Or Import Image Files (JPG / PNG / HEIC)",
                    hint: "Select multiple image files from Files app",
                    icon: "folder.badge.plus",
                    allowedUTIs: FileUtils.imageUTIs,
                    allowsMultiple: true,
                    compact: true,
                    onError: { errorMessage = $0 }
                ) { urls in
                    for url in urls {
                        if let data = try? LocalFileManager.shared.read(from: url),
                           let img = UIImage(data: data) {
                            images.append(img)
                        }
                    }
                    outputURL = nil
                }
            }

            if !images.isEmpty {
                ToolSettingsCard(
                    title: "Page Sequence & Layout",
                    badge: "\(images.count) image\(images.count == 1 ? "" : "s")"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(images.enumerated()), id: \.offset) { idx, img in
                                    VStack(spacing: 6) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 84, height: 106)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(PKColors.border, lineWidth: 1))

                                        HStack(spacing: 4) {
                                            Button {
                                                guard idx > 0 else { return }
                                                images.swapAt(idx, idx - 1)
                                            } label: {
                                                Image(systemName: "chevron.left")
                                                    .font(.caption2.weight(.bold))
                                                    .padding(5)
                                                    .background(PKColors.backgroundInset, in: Circle())
                                            }
                                            .disabled(idx == 0)

                                            Text("\(idx + 1)")
                                                .font(PKFont.mono(.caption2, weight: .bold))

                                            Button {
                                                guard idx < images.count - 1 else { return }
                                                images.swapAt(idx, idx + 1)
                                            } label: {
                                                Image(systemName: "chevron.right")
                                                    .font(.caption2.weight(.bold))
                                                    .padding(5)
                                                    .background(PKColors.backgroundInset, in: Circle())
                                            }
                                            .disabled(idx == images.count - 1)

                                            Button {
                                                images.remove(at: idx)
                                                outputURL = nil
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(PKColors.error)
                                                    .padding(5)
                                                    .background(PKColors.errorSoft, in: Circle())
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Picker("Page Size", selection: $pageSize) {
                            ForEach(PDFPageSizeOption.allCases) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Page Margin: \(Int(marginPoints)) pt")
                                .font(PKFont.mono(.caption, weight: .medium))
                            Slider(value: $marginPoints, in: 0...48, step: 6)
                        }

                        TextField("photos_document", text: $outputName)
                            .font(PKFont.mono(.subheadline, weight: .medium))
                            .padding(10)
                            .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 10))

                        PrimaryButton(
                            title: "Create PDF (\(images.count) Page\(images.count == 1 ? "" : "s"))",
                            icon: "doc.badge.plus",
                            isLoading: isProcessing
                        ) {
                            generatePDF()
                        }
                    }
                }
            }

            if isProcessing {
                LoadingView(message: "Rendering images into PDF document…")
            }

            if let errorMessage {
                ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }

            if let outputURL {
                VStack(alignment: .leading, spacing: 14) {
                    ToolResultCard(
                        title: "PDF Created",
                        subtitle: "Formatted cleanly at \(pageSize.rawValue).",
                        fileURL: outputURL,
                        outputBytes: outputURL.fileSize,
                        metrics: [
                            ("Pages", "\(images.count)"),
                            ("Format", pageSize.rawValue),
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
                }
            }
        }
    }

    private func generatePDF() {
        guard !images.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        outputURL = nil

        let clean = outputName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = clean.isEmpty ? "photos_document" : clean.replacingOccurrences(of: ".pdf", with: "")

        do {
            let result = try pdfService.imagesToPDF(
                images: images,
                pageSize: pageSize,
                marginPoints: marginPoints,
                outputName: "\(base).pdf"
            )
            outputURL = result
            history.record(
                tool: tool,
                inputFileName: "\(images.count) images",
                outputFileName: result.lastPathComponent,
                outputURL: result,
                status: .completed,
                fileSize: result.fileSize,
                fileCount: images.count
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isProcessing = false
    }
}
