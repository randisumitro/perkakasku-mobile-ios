import Foundation
import UIKit
import Vision
import PDFKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum OCRLanguageOption: String, CaseIterable, Identifiable, Sendable {
    case indonesianAndEnglish = "ind+eng"
    case english = "eng"
    case indonesian = "ind"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .indonesianAndEnglish: return "Indonesian + English"
        case .english: return "English"
        case .indonesian: return "Indonesian"
        }
    }

    var recognitionLanguages: [String] {
        switch self {
        case .indonesianAndEnglish: return ["id-ID", "en-US"]
        case .english: return ["en-US"]
        case .indonesian: return ["id-ID"]
        }
    }
}

struct OCRResult: Sendable {
    let text: String
    let pageCount: Int
    let averageConfidence: Int
    let engine: String
}

enum OCRError: LocalizedError, Sendable {
    case invalidInput
    case noTextRecognized

    var errorDescription: String? {
        switch self {
        case .invalidInput: return "Could not load the selected image or PDF for text recognition."
        case .noTextRecognized: return "No readable text was found in this document."
        }
    }
}

/// On-device OCR powered by Apple Vision `VNRecognizeTextRequest` and PDFKit.
@MainActor
final class VisionOCRService: ObservableObject {
    static let shared = VisionOCRService()
    private let ciContext = CIContext()

    private init() {}

    func recognizeImage(
        _ image: UIImage,
        language: OCRLanguageOption,
        enhanceContrast: Bool
    ) async throws -> OCRResult {
        let prepared = enhanceContrast ? enhanceForOCR(image) : ImageService.shared.normalizedOrientation(image)
        guard let cgImage = prepared.cgImage else {
            throw OCRError.invalidInput
        }
        let langs = language.recognitionLanguages
        let (text, conf) = try await Self.runVisionOCR(cgImage: cgImage, languages: langs)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OCRError.noTextRecognized }
        return OCRResult(
            text: trimmed,
            pageCount: 1,
            averageConfidence: conf,
            engine: "Apple Vision OCR"
        )
    }

    func recognizePDF(
        url: URL,
        language: OCRLanguageOption,
        enhanceContrast: Bool,
        onProgress: @escaping @Sendable (Double, String) -> Void
    ) async throws -> OCRResult {
        guard let doc = PDFDocument(url: url), doc.pageCount > 0 else {
            throw OCRError.invalidInput
        }
        let totalPages = min(doc.pageCount, 40)
        let langs = language.recognitionLanguages

        var pageOutputs: [String] = []
        var totalConfidence = 0
        var recognizedPageCount = 0

        for idx in 0..<totalPages {
            let pageNo = idx + 1
            onProgress(Double(idx) / Double(totalPages), "Scanning page \(pageNo) of \(totalPages)…")
            guard let rendered = PDFService.shared.pdfToImages(url: url, dpi: 200, pages: [pageNo]).first else {
                continue
            }
            let prepared = enhanceContrast ? enhanceForOCR(rendered) : rendered
            guard let cgImage = prepared.cgImage else { continue }
            let (pageText, conf) = try await Self.runVisionOCR(cgImage: cgImage, languages: langs)
            let cleaned = pageText.trimmingCharacters(in: .whitespacesAndNewlines)
            if totalPages > 1 {
                pageOutputs.append("=== Page \(pageNo) of \(totalPages) ===\n\(cleaned)")
            } else {
                pageOutputs.append(cleaned)
            }
            if !cleaned.isEmpty {
                totalConfidence += conf
                recognizedPageCount += 1
            }
        }

        let joined = pageOutputs.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joined.isEmpty else { throw OCRError.noTextRecognized }
        onProgress(1.0, "Completed")

        let avgConf = recognizedPageCount > 0 ? totalConfidence / recognizedPageCount : 0
        return OCRResult(
            text: joined,
            pageCount: totalPages,
            averageConfidence: avgConf,
            engine: "Apple Vision OCR + PDFKit"
        )
    }

    private func enhanceForOCR(_ image: UIImage) -> UIImage {
        let upright = ImageService.shared.normalizedOrientation(image)
        guard let cg = upright.cgImage else { return upright }
        let ci = CIImage(cgImage: cg)
        let filter = CIFilter.colorControls()
        filter.inputImage = ci
        filter.saturation = 0.0
        filter.contrast = 1.35
        filter.brightness = 0.03
        guard let out = filter.outputImage,
              let outCG = ciContext.createCGImage(out, from: ci.extent) else {
            return upright
        }
        return UIImage(cgImage: outCG, scale: 1.0, orientation: .up)
    }

    private nonisolated static func runVisionOCR(
        cgImage: CGImage,
        languages: [String]
    ) async throws -> (String, Int) {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            let observations = request.results ?? []
            var lines: [String] = []
            var confidenceSum: Float = 0

            for obs in observations {
                if let candidate = obs.topCandidates(1).first {
                    lines.append(candidate.string)
                    confidenceSum += candidate.confidence
                }
            }

            let avgConf = observations.isEmpty
                ? 0
                : Int(((confidenceSum / Float(observations.count)) * 100).rounded())
            return (lines.joined(separator: "\n"), avgConf)
        }.value
    }
}
