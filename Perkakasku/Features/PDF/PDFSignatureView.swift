// xcode: set sdk=iOS

import SwiftUI
import PencilKit
import PDFKit
import UniformTypeIdentifiers

/// Local PDF signature workbench supporting freehand draw (PencilKit), typed script signature,
/// interactive placement over the selected PDF page, and flattened PDF export.
struct PDFSignatureView: View {
    enum SignatureSource: String, CaseIterable, Identifiable {
        case draw = "Draw"
        case type = "Type"

        var id: String { rawValue }
    }

    enum PlacementPreset: String, CaseIterable, Identifiable {
        case bottomRight = "Bottom Right"
        case bottomCenter = "Bottom Center"
        case bottomLeft = "Bottom Left"
        case custom = "Custom"

        var id: String { rawValue }
    }

    let tool: Tool

    @EnvironmentObject private var pdfService: PDFService
    @EnvironmentObject private var history: HistoryService

    @State private var selectedURL: URL?
    @State private var pageCount: Int = 1
    @State private var selectedPageIndex: Int = 0
    @State private var pageThumbnail: UIImage?
    @State private var pageMediaSize: CGSize = CGSize(width: 595.2, height: 841.8)

    @State private var sourceMode: SignatureSource = .draw
    @State private var canvasView = PKCanvasView()
    @State private var typedSignature: String = "Randi Sumitro"
    @State private var inkColor: UIColor = UIColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1)

    @State private var placementPreset: PlacementPreset = .bottomRight
    @State private var normalizedX: Double = 0.72 // 0...1 center X
    @State private var normalizedY: Double = 0.84 // 0...1 center Y
    @State private var widthRatio: Double = 0.28  // 0.14...0.55 of page width

    @State private var isProcessing = false
    @State private var outputURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileImportButton(
                title: selectedURL == nil ? "Select PDF to Sign" : "Choose Another PDF",
                hint: "Sign directly on device without uploading sensitive documents",
                icon: "signature",
                allowedUTIs: [UTType.pdf.identifier],
                allowsMultiple: false,
                compact: selectedURL != nil,
                onError: { errorMessage = $0 }
            ) { urls in
                guard let url = urls.first else { return }
                loadPDF(url)
            }

            if selectedURL != nil {
                signatureInputCard
                placementPreviewCard
            }

            if isProcessing {
                LoadingView(message: "Embedding crisp vector signature into PDF…")
            }

            if let errorMessage {
                ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }

            if let outputURL {
                VStack(alignment: .leading, spacing: 14) {
                    ToolResultCard(
                        title: "Signed PDF Ready",
                        subtitle: "Signature embedded cleanly onto page \(selectedPageIndex + 1).",
                        fileURL: outputURL,
                        originalBytes: selectedURL?.fileSize,
                        outputBytes: outputURL.fileSize,
                        metrics: [
                            ("Signed Page", "\(selectedPageIndex + 1) / \(pageCount)"),
                            ("Storage", "Local Only"),
                        ],
                        exportLabel: "Export Signed PDF"
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

    private var signatureInputCard: some View {
        ToolSettingsCard(
            title: "1. Create Signature",
            subtitle: "Draw with your finger or type a script signature"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Signature Mode", selection: $sourceMode) {
                    ForEach(SignatureSource.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    Text("Ink Color")
                        .font(PKFont.body(.caption, weight: .semibold))
                        .foregroundStyle(PKColors.textSecondary)
                    Spacer()
                    colorSwatch(UIColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1), label: "Black")
                    colorSwatch(UIColor(red: 0.07, green: 0.25, blue: 0.65, alpha: 1), label: "Navy Ink")
                    colorSwatch(UIColor(red: 0.85, green: 0.27, blue: 0.03, alpha: 1), label: "Orange")
                }

                if sourceMode == .draw {
                    ZStack(alignment: .topTrailing) {
                        PencilKitSignaturePad(canvasView: $canvasView, inkColor: inkColor)
                            .frame(height: 170)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(PKColors.borderStrong, lineWidth: 1)
                            )

                        Button {
                            canvasView.drawing = PKDrawing()
                            PKHaptics.selection()
                        } label: {
                            Label("Clear", systemImage: "eraser")
                                .font(PKFont.body(.caption2, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(PKColors.surfaceElevated, in: Capsule())
                                .overlay(Capsule().strokeBorder(PKColors.border, lineWidth: 1))
                        }
                        .padding(8)
                    }
                } else {
                    TextField("Your full name", text: $typedSignature)
                        .font(.custom("SnellRoundhand-Bold", size: 28))
                        .foregroundStyle(Color(uiColor: inkColor))
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(PKColors.borderStrong, lineWidth: 1)
                        )
                }
            }
        }
    }

    private func colorSwatch(_ color: UIColor, label: String) -> some View {
        let selected = inkColor == color
        return Button {
            inkColor = color
            PKHaptics.selection()
        } label: {
            Circle()
                .fill(Color(uiColor: color))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .strokeBorder(selected ? PKColors.brandVivid : .white, lineWidth: selected ? 2.5 : 1)
                )
        }
        .accessibilityLabel(label)
    }

    private var placementPreviewCard: some View {
        ToolSettingsCard(
            title: "2. Page & Placement",
            badge: "Page \(selectedPageIndex + 1) of \(pageCount)"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if pageCount > 1 {
                    Stepper("Target Page: \(selectedPageIndex + 1)", value: $selectedPageIndex, in: 0...(pageCount - 1))
                        .font(PKFont.body(.subheadline, weight: .semibold))
                        .onChange(of: selectedPageIndex) { _, _ in
                            refreshPagePreview()
                        }
                }

                // Live page thumbnail with placement indicator box
                if let pageThumbnail {
                    GeometryReader { geo in
                        let aspect = pageThumbnail.size.height / max(1, pageThumbnail.size.width)
                        let w = min(geo.size.width, 280 / max(0.5, aspect))
                        let h = w * aspect
                        ZStack {
                            Image(uiImage: pageThumbnail)
                                .resizable()
                                .scaledToFit()
                                .frame(width: w, height: h)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(PKColors.border, lineWidth: 1))

                            let sigW = w * widthRatio
                            let sigH = sigW * 0.42
                            RoundedRectangle(cornerRadius: 4)
                                .fill(PKColors.brandVivid.opacity(0.18))
                                .frame(width: sigW, height: sigH)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(PKColors.brandVivid, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                )
                                .overlay(
                                    Text("SIGN HERE")
                                        .font(PKFont.mono(.caption2, weight: .bold))
                                        .foregroundStyle(PKColors.brand)
                                )
                                .position(x: w * normalizedX, y: h * normalizedY)
                        }
                        .frame(maxWidth: .infinity)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    placementPreset = .custom
                                    let left = (geo.size.width - w) / 2
                                    normalizedX = min(0.88, max(0.12, (value.location.x - left) / max(1, w)))
                                    normalizedY = min(0.92, max(0.08, value.location.y / max(1, h)))
                                }
                        )
                    }
                    .frame(height: 290)
                }

                Picker("Preset", selection: $placementPreset) {
                    ForEach(PlacementPreset.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: placementPreset) { _, preset in
                    switch preset {
                    case .bottomRight: normalizedX = 0.75; normalizedY = 0.85
                    case .bottomCenter: normalizedX = 0.50; normalizedY = 0.85
                    case .bottomLeft: normalizedX = 0.25; normalizedY = 0.85
                    case .custom: break
                    }
                }

                HStack {
                    Text("Signature Size: \(Int(widthRatio * 100))%")
                        .font(PKFont.mono(.caption, weight: .semibold))
                        .foregroundStyle(PKColors.textSecondary)
                    Slider(value: $widthRatio, in: 0.14...0.55)
                }

                PrimaryButton(
                    title: "Apply Signature to PDF",
                    icon: "checkmark.seal.fill",
                    isLoading: isProcessing
                ) {
                    applySignature()
                }
            }
        }
    }

    private func loadPDF(_ url: URL) {
        selectedURL = url
        outputURL = nil
        errorMessage = nil
        pageCount = max(1, pdfService.pageCount(url: url))
        selectedPageIndex = 0
        refreshPagePreview()
        PKHaptics.selection()
    }

    private func refreshPagePreview() {
        guard let url = selectedURL else { return }
        pageThumbnail = pdfService.renderThumbnail(url: url, pageIndex: selectedPageIndex, maxDimension: 520)
        if let doc = PDFDocument(url: url), let page = doc.page(at: selectedPageIndex) {
            pageMediaSize = page.bounds(for: .mediaBox).size
        }
    }

    private func renderCurrentSignatureImage() -> UIImage? {
        switch sourceMode {
        case .draw:
            let bounds = canvasView.drawing.bounds
            guard !bounds.isEmpty else { return nil }
            let padded = bounds.insetBy(dx: -8, dy: -8)
            return canvasView.drawing.image(from: padded, scale: 2.0)

        case .type:
            let clean = typedSignature.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return nil }
            let size = CGSize(width: 600, height: 220)
            let fmt = UIGraphicsImageRendererFormat()
            fmt.scale = 2.0
            fmt.opaque = false
            return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
                let font = UIFont(name: "SnellRoundhand-Bold", size: 78) ?? UIFont.italicSystemFont(ofSize: 64)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: inkColor,
                ]
                let ns = NSString(string: clean)
                let textSize = ns.size(withAttributes: attrs)
                let drawPoint = CGPoint(
                    x: max(12, (size.width - textSize.width) / 2),
                    y: max(12, (size.height - textSize.height) / 2)
                )
                ns.draw(at: drawPoint, withAttributes: attrs)
            }
        }
    }

    private func applySignature() {
        guard let url = selectedURL else { return }
        guard let sigImage = renderCurrentSignatureImage() else {
            errorMessage = "Please draw or type a signature before applying."
            PKHaptics.error()
            return
        }

        isProcessing = true
        errorMessage = nil
        outputURL = nil

        let targetW = pageMediaSize.width * widthRatio
        let sigAspect = sigImage.size.height / max(1, sigImage.size.width)
        let targetH = min(pageMediaSize.height * 0.35, targetW * sigAspect)

        let bounds = CGRect(
            x: pageMediaSize.width * normalizedX - targetW / 2,
            y: pageMediaSize.height * normalizedY - targetH / 2,
            width: targetW,
            height: targetH
        )

        let outName = FileUtils.outputFileName(input: url.lastPathComponent, suffix: "_signed", ext: "pdf")
        do {
            let signed = try pdfService.sign(
                url: url,
                signatureImage: sigImage,
                bounds: bounds,
                pageIndex: selectedPageIndex,
                outputName: outName
            )
            outputURL = signed
            history.record(
                tool: tool,
                inputFileName: url.lastPathComponent,
                outputFileName: signed.lastPathComponent,
                outputURL: signed,
                status: .completed,
                fileSize: signed.fileSize
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }

        isProcessing = false
    }
}

private struct PencilKitSignaturePad: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let inkColor: UIColor

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.tool = PKInkingTool(.pen, color: inkColor, width: 3.5)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = PKInkingTool(.pen, color: inkColor, width: 3.5)
    }
}
