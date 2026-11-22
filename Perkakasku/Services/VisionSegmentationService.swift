import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct SegmentationResult: Sendable {
    let cutoutImage: UIImage
    let pngData: Data
    let engineName: String
}

enum SegmentationError: LocalizedError, Sendable {
    case invalidImage
    case noSubjectFound
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not read the input image."
        case .noSubjectFound: return "No distinct foreground subject was detected in this photo."
        case .renderFailed: return "Failed to generate transparent PNG output."
        }
    }
}

/// On-device subject cutout service powered by Apple Vision + CoreImage.
@MainActor
final class VisionSegmentationService: ObservableObject {
    static let shared = VisionSegmentationService()
    private let ciContext = CIContext()

    private init() {}

    func removeBackground(from image: UIImage) async throws -> SegmentationResult {
        let upright = ImageService.shared.normalizedOrientation(image)
        guard let cgImage = upright.cgImage else {
            throw SegmentationError.invalidImage
        }

        let ctx = ciContext
        return try await Task.detached(priority: .userInitiated) {
            let ciInput = CIImage(cgImage: cgImage)

            // 1. Primary path: Vision Foreground Instance Mask (iOS 17+)
            if #available(iOS 17.0, *) {
                do {
                    let request = VNGenerateForegroundInstanceMaskRequest()
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try handler.perform([request])
                    if let observation = request.results?.first, !observation.allInstances.isEmpty {
                        let maskBuffer = try observation.generateScaledMaskForImage(
                            forInstances: observation.allInstances,
                            from: handler
                        )
                        let maskCI = CIImage(cvPixelBuffer: maskBuffer)
                        if let output = Self.composite(input: ciInput, mask: maskCI, context: ctx) {
                            return SegmentationResult(
                                cutoutImage: output.image,
                                pngData: output.pngData,
                                engineName: "Apple Vision Subject AI"
                            )
                        }
                    }
                } catch {
                    // Fall through to person segmentation or border-matte extraction (e.g. simulator runtime fallback)
                }
            }

            // 2. Secondary path: Vision Person Segmentation (portrait & passport photos)
            do {
                let personReq = VNGeneratePersonSegmentationRequest()
                personReq.qualityLevel = .accurate
                personReq.outputPixelFormat = kCVPixelFormatType_OneComponent8
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([personReq])
                if let maskBuffer = personReq.results?.first?.pixelBuffer {
                    let rawMask = CIImage(cvPixelBuffer: maskBuffer)
                    let sx = ciInput.extent.width / max(1, rawMask.extent.width)
                    let sy = ciInput.extent.height / max(1, rawMask.extent.height)
                    let scaledMask = rawMask.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
                    if let output = Self.composite(input: ciInput, mask: scaledMask, context: ctx) {
                        return SegmentationResult(
                            cutoutImage: output.image,
                            pngData: output.pngData,
                            engineName: "Apple Vision Portrait AI"
                        )
                    }
                }
            } catch {
                // Fall through to uniform-backdrop color distance segmentation
            }

            // 3. Deterministic backdrop chroma/luminance fallback (ideal for solid backdrops or simulator CPU fallback)
            if let fallback = Self.uniformBackdropFallback(cgImage: cgImage) {
                return SegmentationResult(
                    cutoutImage: fallback.image,
                    pngData: fallback.pngData,
                    engineName: "CoreImage Backdrop Extraction"
                )
            }

            throw SegmentationError.noSubjectFound
        }.value
    }

    nonisolated func compositeWithMatte(cutout: UIImage, backgroundColor: UIColor?, asPNG: Bool, quality: CGFloat = 0.92) -> (image: UIImage, data: Data)? {
        let upright = cutout
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        fmt.opaque = backgroundColor != nil
        let size = upright.size
        let composited = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            if let bg = backgroundColor {
                bg.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            upright.draw(in: CGRect(origin: .zero, size: size))
        }
        let data = (backgroundColor == nil || asPNG)
            ? composited.pngData()
            : composited.jpegData(compressionQuality: max(0.5, min(1.0, quality)))
        guard let data else { return nil }
        return (composited, data)
    }

    private nonisolated static func composite(input: CIImage, mask: CIImage, context: CIContext) -> (image: UIImage, pngData: Data)? {
        let filter = CIFilter.blendWithMask()
        filter.inputImage = input
        filter.backgroundImage = CIImage.empty()
        filter.maskImage = mask
        guard let result = filter.outputImage,
              let outCG = context.createCGImage(result, from: input.extent) else {
            return nil
        }
        let uiImg = UIImage(cgImage: outCG, scale: 1.0, orientation: .up)
        guard let pngData = uiImg.pngData() else { return nil }
        return (uiImg, pngData)
    }

    private nonisolated static func uniformBackdropFallback(cgImage: CGImage) -> (image: UIImage, pngData: Data)? {
        let w = cgImage.width
        let h = cgImage.height
        guard w > 2, h > 2 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = w * bytesPerPixel
        var rgba = [UInt8](repeating: 0, count: h * bytesPerRow)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: &rgba,
                  width: w,
                  height: h,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        // Sample corners to estimate background color
        let corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
        var sumR = 0, sumG = 0, sumB = 0
        for (cx, cy) in corners {
            let idx = (cy * w + cx) * 4
            sumR += Int(rgba[idx])
            sumG += Int(rgba[idx + 1])
            sumB += Int(rgba[idx + 2])
        }
        let bgR = Float(sumR) / 4.0
        let bgG = Float(sumG) / 4.0
        let bgB = Float(sumB) / 4.0

        var transparentPixels = 0
        for i in stride(from: 0, to: rgba.count, by: 4) {
            let dr = Float(rgba[i]) - bgR
            let dg = Float(rgba[i + 1]) - bgG
            let db = Float(rgba[i + 2]) - bgB
            let dist = sqrt(dr * dr + dg * dg + db * db)
            if dist < 42 {
                rgba[i] = 0
                rgba[i + 1] = 0
                rgba[i + 2] = 0
                rgba[i + 3] = 0
                transparentPixels += 1
            } else if dist < 68 {
                let alpha = (dist - 42) / 26.0
                let a = UInt8(max(0, min(255, alpha * 255)))
                rgba[i] = UInt8(Float(rgba[i]) * alpha)
                rgba[i + 1] = UInt8(Float(rgba[i + 1]) * alpha)
                rgba[i + 2] = UInt8(Float(rgba[i + 2]) * alpha)
                rgba[i + 3] = a
            }
        }

        // Only succeed if we actually masked some backdrop without erasing everything
        guard transparentPixels > 0, transparentPixels < (w * h) else { return nil }
        guard let outCG = ctx.makeImage() else { return nil }
        let outImage = UIImage(cgImage: outCG, scale: 1.0, orientation: .up)
        guard let pngData = outImage.pngData() else { return nil }
        return (outImage, pngData)
    }
}
