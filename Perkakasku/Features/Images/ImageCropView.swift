// xcode: set sdk=iOS

import SwiftUI

/// Interactive image cropper & 90-degree rotator with fixed & free aspect ratio presets.
struct ImageCropView: View {
    enum AspectPreset: String, CaseIterable, Identifiable {
        case free = "Free"
        case square = "1:1"
        case r4x3 = "4:3"
        case r3x2 = "3:2"
        case r16x9 = "16:9"
        case r9x16 = "9:16"
        case r2x3 = "2:3"

        var id: String { rawValue }

        var ratio: CGFloat? {
            switch self {
            case .free: return nil
            case .square: return 1.0
            case .r4x3: return 4.0 / 3.0
            case .r3x2: return 3.0 / 2.0
            case .r16x9: return 16.0 / 9.0
            case .r9x16: return 9.0 / 16.0
            case .r2x3: return 2.0 / 3.0
            }
        }
    }

    enum ExportFmt: String, CaseIterable, Identifiable {
        case png = "PNG"
        case jpg = "JPG"

        var id: String { rawValue }
    }

    let tool: Tool

    @EnvironmentObject private var imageService: ImageService
    @EnvironmentObject private var history: HistoryService

    @State private var sourceImage: UIImage?
    @State private var sourceName: String = "image.png"
    @State private var aspect: AspectPreset = .free
    @State private var exportFormat: ExportFmt = .png

    // Normalized crop box in 0...1 image coordinates
    @State private var cropLeft: Double = 0.08
    @State private var cropTop: Double = 0.08
    @State private var cropRight: Double = 0.92
    @State private var cropBottom: Double = 0.92

    @State private var outputImage: UIImage?
    @State private var outputURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 10) {
                PhotoImportButton(
                    title: sourceImage == nil ? "Pick Photo to Crop" : "Choose Another Photo",
                    maxSelectionCount: 1,
                    compact: sourceImage != nil
                ) { imgs in
                    guard let img = imgs.first else { return }
                    setSource(img, name: "photo_\(Int(Date().timeIntervalSince1970)).png")
                }

                FileImportButton(
                    title: "Or Import Image File",
                    hint: "JPG, PNG, HEIC",
                    icon: "folder.badge.plus",
                    allowedUTIs: FileUtils.imageUTIs,
                    allowsMultiple: false,
                    compact: true,
                    onError: { errorMessage = $0 }
                ) { urls in
                    guard let url = urls.first,
                          let data = try? LocalFileManager.shared.read(from: url),
                          let img = UIImage(data: data) else {
                        errorMessage = "Could not load selected image."
                        return
                    }
                    setSource(img, name: url.lastPathComponent)
                }
            }

            if let sourceImage {
                cropStudioCard(sourceImage)
            }

            if let errorMessage {
                ErrorView(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }

            if let outputURL, let outputImage {
                VStack(alignment: .leading, spacing: 14) {
                    ToolResultCard(
                        title: "Cropped Image Ready",
                        subtitle: "Saved crisply in \(exportFormat.rawValue).",
                        fileURL: outputURL,
                        outputBytes: outputURL.fileSize,
                        metrics: [
                            ("Cropped Pixels", "\(Int(outputImage.size.width)) × \(Int(outputImage.size.height))"),
                            ("Aspect", aspect.rawValue),
                        ],
                        exportLabel: "Export \(exportFormat.rawValue)",
                        imageToSave: outputImage
                    )

                    Image(uiImage: outputImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: PKRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: PKRadius.md).strokeBorder(PKColors.border, lineWidth: 1))
                }
            }
        }
    }

    private func cropStudioCard(_ image: UIImage) -> some View {
        let pxW = Int(round((cropRight - cropLeft) * image.size.width))
        let pxH = Int(round((cropBottom - cropTop) * image.size.height))

        return ToolSettingsCard(
            title: "Crop Frame & Rotate",
            badge: "\(max(1, pxW)) × \(max(1, pxH)) px"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                GeometryReader { geo in
                    let imgAspect = image.size.width / max(1, image.size.height)
                    let maxH: CGFloat = 260
                    let dispW = min(geo.size.width, maxH * imgAspect)
                    let dispH = dispW / imgAspect

                    let rectX = cropLeft * dispW
                    let rectY = cropTop * dispH
                    let rectW = max(24, (cropRight - cropLeft) * dispW)
                    let rectH = max(24, (cropBottom - cropTop) * dispH)

                    ZStack(alignment: .topLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: dispW, height: dispH)

                        // Dark scrim outside selection
                        Color.black.opacity(0.45)
                            .frame(width: dispW, height: dispH)
                            .mask(
                                Canvas { ctx, size in
                                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                                    ctx.blendMode = .destinationOut
                                    ctx.fill(Path(CGRect(x: rectX, y: rectY, width: rectW, height: rectH)), with: .color(.white))
                                }
                            )

                        Rectangle()
                            .strokeBorder(PKColors.brandVivid, lineWidth: 2)
                            .background(Color.white.opacity(0.01))
                            .frame(width: rectW, height: rectH)
                            .position(x: rectX + rectW / 2, y: rectY + rectH / 2)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let dx = value.translation.width / max(1, dispW)
                                        let dy = value.translation.height / max(1, dispH)
                                        let boxW = cropRight - cropLeft
                                        let boxH = cropBottom - cropTop
                                        let newL = max(0, min(1 - boxW, cropLeft + dx * 0.25))
                                        let newT = max(0, min(1 - boxH, cropTop + dy * 0.25))
                                        cropLeft = newL
                                        cropRight = newL + boxW
                                        cropTop = newT
                                        cropBottom = newT + boxH
                                    }
                            )
                    }
                    .frame(width: dispW, height: dispH)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity, maxHeight: maxH)
                }
                .frame(height: 264)

                // Inset / Size Sliders for precise edge control
                VStack(spacing: 8) {
                    HStack {
                        Text("Width")
                            .font(PKFont.mono(.caption2, weight: .bold))
                            .frame(width: 52, alignment: .leading)
                        Slider(value: Binding(
                            get: { cropRight - cropLeft },
                            set: { newW in
                                let clampedW = max(0.15, min(1.0, newW))
                                let center = (cropLeft + cropRight) / 2
                                let newL = max(0, min(1 - clampedW, center - clampedW / 2))
                                cropLeft = newL
                                cropRight = newL + clampedW
                                enforceAspectIfNeeded(on: image)
                            }
                        ), in: 0.15...1.0)
                    }

                    if aspect == .free {
                        HStack {
                            Text("Height")
                                .font(PKFont.mono(.caption2, weight: .bold))
                                .frame(width: 52, alignment: .leading)
                            Slider(value: Binding(
                                get: { cropBottom - cropTop },
                                set: { newH in
                                    let clampedH = max(0.15, min(1.0, newH))
                                    let center = (cropTop + cropBottom) / 2
                                    let newT = max(0, min(1 - clampedH, center - clampedH / 2))
                                    cropTop = newT
                                    cropBottom = newT + clampedH
                                }
                            ), in: 0.15...1.0)
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AspectPreset.allCases) { preset in
                            let active = aspect == preset
                            Button {
                                aspect = preset
                                enforceAspectIfNeeded(on: image)
                                PKHaptics.selection()
                            } label: {
                                Text(preset.rawValue)
                                    .font(PKFont.mono(.caption, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .foregroundStyle(active ? .white : PKColors.textPrimary)
                                    .background(active ? PKColors.brandVivid : PKColors.backgroundInset, in: Capsule())
                                    .overlay(Capsule().strokeBorder(active ? Color.clear : PKColors.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        sourceImage = imageService.rotate90(image)
                        resetCropBox()
                        PKHaptics.selection()
                    } label: {
                        Label("Rotate 90°", systemImage: "rotate.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))

                    Button {
                        aspect = .free
                        resetCropBox()
                        PKHaptics.selection()
                    } label: {
                        Label("Reset Crop", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))
                }

                Picker("Export Format", selection: $exportFormat) {
                    ForEach(ExportFmt.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)

                PrimaryButton(title: "Apply Crop", icon: "crop") {
                    applyCrop(image)
                }
            }
        }
    }

    private func setSource(_ img: UIImage, name: String) {
        sourceImage = imageService.normalizedOrientation(img)
        sourceName = name
        outputImage = nil
        outputURL = nil
        errorMessage = nil
        resetCropBox()
        PKHaptics.selection()
    }

    private func resetCropBox() {
        cropLeft = 0.05
        cropTop = 0.05
        cropRight = 0.95
        cropBottom = 0.95
    }

    private func enforceAspectIfNeeded(on image: UIImage) {
        guard let ratio = aspect.ratio, image.size.height > 0 else { return }
        let pixelW = (cropRight - cropLeft) * image.size.width
        var pixelH = pixelW / ratio
        var normH = pixelH / image.size.height
        if normH > 1.0 {
            normH = 0.95
            pixelH = normH * image.size.height
            let newNormW = min(1.0, (pixelH * ratio) / image.size.width)
            let cX = (cropLeft + cropRight) / 2
            cropLeft = max(0, min(1 - newNormW, cX - newNormW / 2))
            cropRight = cropLeft + newNormW
        }
        let cY = (cropTop + cropBottom) / 2
        cropTop = max(0, min(1 - normH, cY - normH / 2))
        cropBottom = cropTop + normH
    }

    private func applyCrop(_ image: UIImage) {
        let pxW = image.size.width
        let pxH = image.size.height
        let cropRect = CGRect(
            x: cropLeft * pxW,
            y: cropTop * pxH,
            width: (cropRight - cropLeft) * pxW,
            height: (cropBottom - cropTop) * pxH
        )
        guard let cropped = imageService.crop(image: image, to: cropRect) else {
            errorMessage = "Crop rectangle could not be applied."
            PKHaptics.error()
            return
        }

        let fmt: ImageService.Format = exportFormat == .png ? .png : .jpeg(quality: 0.94)
        guard let data = imageService.convert(image: cropped, to: fmt) else {
            errorMessage = "Failed to encode cropped image."
            PKHaptics.error()
            return
        }

        let ext = exportFormat == .png ? "png" : "jpg"
        let outName = FileUtils.outputFileName(input: sourceName, suffix: "_cropped", ext: ext)
        let dest = LocalFileManager.shared.documentsURL(for: outName)

        do {
            try LocalFileManager.shared.write(data: data, to: dest)
            outputImage = cropped
            outputURL = dest
            history.record(
                tool: tool,
                inputFileName: sourceName,
                outputFileName: dest.lastPathComponent,
                outputURL: dest,
                status: .completed,
                fileSize: Int64(data.count)
            )
            PKHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            PKHaptics.error()
        }
    }
}
