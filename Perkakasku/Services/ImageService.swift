import Foundation
import UIKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

enum PassportSizePreset: String, CaseIterable, Identifiable, Sendable {
    case size2x3 = "2x3"
    case size3x4 = "3x4"
    case size4x6 = "4x6"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .size2x3: return "2 × 3 cm"
        case .size3x4: return "3 × 4 cm"
        case .size4x6: return "4 × 6 cm"
        }
    }

    var pixelSize300DPI: CGSize {
        switch self {
        case .size2x3: return CGSize(width: 236, height: 354)
        case .size3x4: return CGSize(width: 354, height: 472)
        case .size4x6: return CGSize(width: 472, height: 708)
        }
    }

    var aspectRatio: CGFloat {
        pixelSize300DPI.width / pixelSize300DPI.height
    }

    var hint: String {
        let s = pixelSize300DPI
        return "\(Int(s.width))×\(Int(s.height)) px • 300 DPI"
    }
}

@MainActor
final class ImageService: ObservableObject {
    static let shared = ImageService()
    private let context = CIContext()
    private init() {}

    enum Format: Sendable, Hashable {
        case jpeg(quality: CGFloat)
        case png
        case heic(quality: CGFloat)
    }

    // MARK: - Orientation Normalization

    /// Flatten EXIF orientation into upright pixel buffer so cropping/resizing coordinates are exact.
    func normalizedOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    // MARK: - Compress

    func compress(image: UIImage, quality: CGFloat = 0.7) -> Data? {
        let upright = normalizedOrientation(image)
        return encode(image: upright, format: .jpeg(quality: quality), flattenWhiteForJPEG: true)
    }

    // MARK: - Resize & Convert

    func resize(image: UIImage, to targetSize: CGSize, opaque: Bool = false) -> UIImage? {
        let safeW = max(1, round(targetSize.width))
        let safeH = max(1, round(targetSize.height))
        let upright = normalizedOrientation(image)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = opaque
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: safeW, height: safeH), format: format)
        return renderer.image { ctx in
            if opaque {
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: CGSize(width: safeW, height: safeH)))
            }
            upright.draw(in: CGRect(origin: .zero, size: CGSize(width: safeW, height: safeH)))
        }
    }

    func convert(image: UIImage, to format: Format) -> Data? {
        let flatten = {
            if case .jpeg = format { return true }
            if case .heic = format { return true }
            return false
        }()
        return encode(image: normalizedOrientation(image), format: format, flattenWhiteForJPEG: flatten)
    }

    private func encode(image: UIImage, format: Format, flattenWhiteForJPEG: Bool) -> Data? {
        let prepared: UIImage
        if flattenWhiteForJPEG {
            let fmt = UIGraphicsImageRendererFormat()
            fmt.scale = 1.0
            fmt.opaque = true
            prepared = UIGraphicsImageRenderer(size: image.size, format: fmt).image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: image.size))
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
        } else {
            prepared = image
        }

        switch format {
        case .jpeg(let q):
            return prepared.jpegData(compressionQuality: max(0.05, min(1.0, q)))
        case .png:
            return prepared.pngData()
        case .heic(let q):
            guard let cg = prepared.cgImage else { return nil }
            let data = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil) else {
                return prepared.jpegData(compressionQuality: q)
            }
            let opts: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: max(0.05, min(1.0, q))]
            CGImageDestinationAddImage(dest, cg, opts as CFDictionary)
            return CGImageDestinationFinalize(dest) ? (data as Data) : nil
        }
    }

    // MARK: - Crop

    func crop(image: UIImage, to rect: CGRect) -> UIImage? {
        let upright = normalizedOrientation(image)
        guard let cg = upright.cgImage else { return nil }
        let pixelBounds = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        let clamped = rect.intersection(pixelBounds)
        guard !clamped.isNull, clamped.width >= 1, clamped.height >= 1,
              let cropped = cg.cropping(to: clamped) else { return nil }
        return UIImage(cgImage: cropped, scale: 1.0, orientation: .up)
    }

    func rotate90(_ image: UIImage) -> UIImage {
        let upright = normalizedOrientation(image)
        let newSize = CGSize(width: upright.size.height, height: upright.size.width)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        fmt.opaque = false
        return UIGraphicsImageRenderer(size: newSize, format: fmt).image { ctx in
            ctx.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            ctx.cgContext.rotate(by: .pi / 2)
            upright.draw(in: CGRect(
                x: -upright.size.width / 2,
                y: -upright.size.height / 2,
                width: upright.size.width,
                height: upright.size.height
            ))
        }
    }

    // MARK: - HEIC to JPG (with EXIF / GPS stripping control)

    func heicToJPG(data: Data, quality: CGFloat = 0.9, stripMetadata: Bool = true) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let upright = normalizedOrientation(image)
        guard let cg = upright.cgImage else { return nil }

        let outData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(outData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return upright.jpegData(compressionQuality: quality)
        }

        var props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: max(0.1, min(1.0, quality))
        ]
        if !stripMetadata,
           let source = CGImageSourceCreateWithData(data as CFData, nil),
           let srcProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            for (k, v) in srcProps where k != kCGImagePropertyOrientation {
                props[k] = v
            }
        }
        CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        return CGImageDestinationFinalize(dest) ? (outData as Data) : upright.jpegData(compressionQuality: quality)
    }

    // MARK: - Passport Photo 300 DPI Render + Metadata Injection

    func renderPassportPhoto(
        image: UIImage,
        preset: PassportSizePreset,
        backgroundColor: UIColor?,
        zoom: CGFloat = 1.0,
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0,
        rotationDegrees: CGFloat = 0,
        asPNG: Bool = false,
        quality: CGFloat = 0.92,
        dpi: Int = 300
    ) -> (image: UIImage, data: Data)? {
        let upright = normalizedOrientation(image)
        let targetSize = preset.pixelSize300DPI
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        fmt.opaque = backgroundColor != nil

        let rendered = UIGraphicsImageRenderer(size: targetSize, format: fmt).image { ctx in
            if let bg = backgroundColor {
                bg.setFill()
                ctx.fill(CGRect(origin: .zero, size: targetSize))
            }

            let rot90 = Int(abs(rotationDegrees)) % 180 == 90
            let effW = max(1, rot90 ? upright.size.height : upright.size.width)
            let effH = max(1, rot90 ? upright.size.width : upright.size.height)

            let coverScale = max(targetSize.width / effW, targetSize.height / effH)
            let scale = coverScale * max(1.0, zoom)
            let drawW = upright.size.width * scale
            let drawH = upright.size.height * scale
            let effDrawW = effW * scale
            let effDrawH = effH * scale

            let maxShiftX = max(0, (effDrawW - targetSize.width) / 2)
            let maxShiftY = max(0, (effDrawH - targetSize.height) / 2)
            let clampedX = max(-1, min(1, offsetX))
            let clampedY = max(-1, min(1, offsetY))
            let centerX = targetSize.width / 2 + clampedX * maxShiftX
            let centerY = targetSize.height / 2 + clampedY * maxShiftY

            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: centerX, y: centerY)
            ctx.cgContext.rotate(by: rotationDegrees * .pi / 180.0)
            upright.draw(in: CGRect(x: -drawW / 2, y: -drawH / 2, width: drawW, height: drawH))
            ctx.cgContext.restoreGState()
        }

        guard let cg = rendered.cgImage else { return nil }
        let uti = (asPNG || backgroundColor == nil) ? UTType.png.identifier : UTType.jpeg.identifier
        let outData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(outData, uti as CFString, 1, nil) else {
            return nil
        }

        var props: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
        ]
        if uti == UTType.jpeg.identifier {
            props[kCGImageDestinationLossyCompressionQuality] = max(0.5, min(1.0, quality))
        }
        CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return (rendered, outData as Data)
    }

    // MARK: - QR Code Generation (PNG + Vector SVG)

    func generateQRCode(
        from string: String,
        size: CGSize = CGSize(width: 600, height: 600),
        foreground: UIColor = .black,
        background: UIColor = .white
    ) -> UIImage? {
        guard !string.isEmpty,
              let data = string.data(using: .utf8),
              let qrFilter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue("Q", forKey: "inputCorrectionLevel")
        guard let qrOutput = qrFilter.outputImage else { return nil }

        let colored: CIImage
        if let colorFilter = CIFilter(name: "CIFalseColor") {
            colorFilter.setValue(qrOutput, forKey: kCIInputImageKey)
            colorFilter.setValue(CIColor(color: foreground), forKey: "inputColor0")
            colorFilter.setValue(CIColor(color: background), forKey: "inputColor1")
            colored = colorFilter.outputImage ?? qrOutput
        } else {
            colored = qrOutput
        }

        let extent = colored.extent
        let scaleX = size.width / extent.width
        let scaleY = size.height / extent.height
        let scaled = colored.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Generate crisp scalable SVG markup matching the QR Code matrix generated by CoreImage.
    func generateQRCodeSVG(
        from string: String,
        sizePx: Int = 512,
        marginModules: Int = 2,
        foregroundHex: String = "#181614",
        backgroundHex: String = "#FFFFFF"
    ) -> String? {
        guard !string.isEmpty,
              let data = string.data(using: .utf8),
              let qrFilter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue("Q", forKey: "inputCorrectionLevel")
        guard let output = qrFilter.outputImage else { return nil }

        let extent = output.extent.integral
        let cols = Int(extent.width)
        let rows = Int(extent.height)
        guard cols > 0, rows > 0,
              let cg = context.createCGImage(output, from: extent) else { return nil }

        // Read 1-byte per pixel grayscale luminance
        let width = cg.width
        let height = cg.height
        var pixels = [UInt8](repeating: 255, count: width * height)
        guard let graySpace = CGColorSpace(name: CGColorSpace.linearGray),
              let ctx = CGContext(
                  data: &pixels,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width,
                  space: graySpace,
                  bitmapInfo: CGImageAlphaInfo.none.rawValue
              ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        let total = cols + marginModules * 2
        var pathCommands: [String] = []
        for y in 0..<height {
            for x in 0..<width {
                if pixels[y * width + x] < 128 {
                    pathCommands.append("M\(x + marginModules),\(y + marginModules)h1v1h-1z")
                }
            }
        }

        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(sizePx)" height="\(sizePx)" viewBox="0 0 \(total) \(total)" shape-rendering="crispEdges">
          <rect width="100%" height="100%" fill="\(backgroundHex)"/>
          <path d="\(pathCommands.joined())" fill="\(foregroundHex)"/>
        </svg>
        """
    }
}
