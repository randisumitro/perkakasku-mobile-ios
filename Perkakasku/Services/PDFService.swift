import Foundation
import UIKit
import PDFKit

enum PDFPageSizeOption: String, CaseIterable, Identifiable, Sendable {
    case autoFit = "Auto Fit"
    case a4 = "A4"
    case letter = "Letter"

    var id: String { rawValue }
}

enum PDFImageFormat: String, CaseIterable, Identifiable, Sendable {
    case png = "PNG"
    case jpg = "JPG"

    var id: String { rawValue }

    var fileExtension: String {
        self == .png ? "png" : "jpg"
    }
}

enum PDFWatermarkPosition: String, CaseIterable, Identifiable, Sendable {
    case center = "Center"
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"

    var id: String { rawValue }
}

struct PDFWatermarkOptions: Sendable {
    enum Content: Sendable {
        case text(String, color: UIColor, fontSizeRatio: CGFloat)
        case image(UIImage)
    }

    let content: Content
    let position: PDFWatermarkPosition
    let opacity: CGFloat
    let rotationDegrees: CGFloat
    let pageNumbers: [Int]? // 1-based; nil = all pages
}

@MainActor
final class PDFService: ObservableObject {
    static let shared = PDFService()
    private let fileManager = LocalFileManager.shared
    private init() {}

    // MARK: - Inspection & Range Parsing

    func pageCount(url: URL) -> Int {
        PDFDocument(url: url)?.pageCount ?? 0
    }

    func parsePageRanges(_ spec: String, maxPage: Int) -> [Int] {
        guard maxPage > 0 else { return [] }
        var pages = Set<Int>()
        for rawPart in spec.split(separator: ",") {
            let part = rawPart.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !part.isEmpty else { continue }
            if part.contains("-") {
                let bounds = part.split(separator: "-").map { Int($0.trimmingCharacters(in: .whitespaces)) }
                if bounds.count == 2, let a = bounds[0], let b = bounds[1], a >= 1, b >= a {
                    for p in a...min(b, maxPage) {
                        pages.insert(p)
                    }
                }
            } else if let p = Int(part), p >= 1, p <= maxPage {
                pages.insert(p)
            }
        }
        return pages.sorted()
    }

    func renderThumbnail(url: URL, pageIndex: Int = 0, maxDimension: CGFloat = 420) -> UIImage? {
        guard let doc = PDFDocument(url: url),
              pageIndex >= 0, pageIndex < doc.pageCount,
              let page = doc.page(at: pageIndex) else { return nil }
        let pageRect = page.bounds(for: .mediaBox)
        guard pageRect.width > 0, pageRect.height > 0 else { return nil }
        let scale = min(maxDimension / pageRect.width, maxDimension / pageRect.height)
        let size = CGSize(width: max(1, pageRect.width * scale), height: max(1, pageRect.height * scale))
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    // MARK: - Local Compression Fallback

    func compressLocally(url: URL, outputName: String = "compressed.pdf") throws -> (url: URL, pageCount: Int) {
        guard let doc = PDFDocument(url: url), doc.pageCount > 0 else {
            throw PDFServiceError.invalidPDF
        }
        let outputURL = fileManager.documentsURL(for: outputName)
        guard doc.write(to: outputURL) else {
            throw PDFServiceError.writeFailed
        }
        return (outputURL, doc.pageCount)
    }

    // MARK: - Merge

    func merge(urls: [URL], outputName: String = "merged.pdf") throws -> URL {
        let outputURL = fileManager.documentsURL(for: outputName)
        let outputDocument = PDFDocument()
        for url in urls {
            guard let doc = PDFDocument(url: url) else { continue }
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i) {
                    outputDocument.insert(page, at: outputDocument.pageCount)
                }
            }
        }
        guard outputDocument.pageCount > 0 else { throw PDFServiceError.invalidPDF }
        guard outputDocument.write(to: outputURL) else { throw PDFServiceError.writeFailed }
        return outputURL
    }

    // MARK: - Split

    func split(url: URL, pages: [Int]? = nil, outputPrefix: String = "page") throws -> [URL] {
        guard let doc = PDFDocument(url: url), doc.pageCount > 0 else {
            throw PDFServiceError.invalidPDF
        }
        let targetPages: [Int]
        if let pages, !pages.isEmpty {
            targetPages = pages.filter { $0 >= 1 && $0 <= doc.pageCount }
        } else {
            targetPages = Array(1...doc.pageCount)
        }
        guard !targetPages.isEmpty else { throw PDFServiceError.invalidPageSelection }

        var outputs: [URL] = []
        for pageNumber in targetPages {
            guard let page = doc.page(at: pageNumber - 1) else { continue }
            let newDoc = PDFDocument()
            newDoc.insert(page, at: 0)
            let name = "\(outputPrefix)_\(String(format: "%03d", pageNumber)).pdf"
            let outURL = fileManager.documentsURL(for: name)
            guard newDoc.write(to: outURL) else { throw PDFServiceError.writeFailed }
            outputs.append(outURL)
        }
        return outputs
    }

    func extractCombinedRange(url: URL, pages: [Int], outputName: String = "extracted.pdf") throws -> URL {
        guard let doc = PDFDocument(url: url), doc.pageCount > 0 else {
            throw PDFServiceError.invalidPDF
        }
        let outDoc = PDFDocument()
        for pageNo in pages where pageNo >= 1 && pageNo <= doc.pageCount {
            if let page = doc.page(at: pageNo - 1) {
                outDoc.insert(page, at: outDoc.pageCount)
            }
        }
        guard outDoc.pageCount > 0 else { throw PDFServiceError.invalidPageSelection }
        let outURL = fileManager.documentsURL(for: outputName)
        guard outDoc.write(to: outURL) else { throw PDFServiceError.writeFailed }
        return outURL
    }

    // MARK: - PDF to Images

    func pdfToImages(url: URL, maxPage: Int? = nil, dpi: CGFloat = 150, pages: [Int]? = nil) -> [UIImage] {
        guard let doc = PDFDocument(url: url), doc.pageCount > 0 else { return [] }
        let scale = max(1.0, min(dpi / 72.0, 4.5))

        let indices: [Int]
        if let pages, !pages.isEmpty {
            indices = pages.map { $0 - 1 }.filter { $0 >= 0 && $0 < doc.pageCount }
        } else {
            let count = min(maxPage ?? doc.pageCount, doc.pageCount)
            indices = Array(0..<count)
        }

        var images: [UIImage] = []
        for idx in indices {
            autoreleasepool {
                guard let page = doc.page(at: idx) else { return }
                let pageRect = page.bounds(for: .mediaBox)
                guard pageRect.width > 0, pageRect.height > 0 else { return }
                let renderSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1.0
                format.opaque = true
                let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
                let image = renderer.image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: renderSize))
                    ctx.cgContext.translateBy(x: 0, y: renderSize.height)
                    ctx.cgContext.scaleBy(x: scale, y: -scale)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }
                images.append(image)
            }
        }
        return images
    }

    // MARK: - Images to PDF

    func imagesToPDF(
        images: [UIImage],
        pageSize: PDFPageSizeOption = .autoFit,
        marginPoints: CGFloat = 0,
        outputName: String = "images.pdf"
    ) throws -> URL {
        guard !images.isEmpty else { throw PDFServiceError.invalidInput }
        let outputURL = fileManager.documentsURL(for: outputName)

        let doc = PDFDocument()
        for rawImage in images {
            let image = ImageService.shared.normalizedOrientation(rawImage)
            switch pageSize {
            case .autoFit:
                let imgSize = image.size
                let bounds = CGRect(origin: .zero, size: CGSize(
                    width: imgSize.width + marginPoints * 2,
                    height: imgSize.height + marginPoints * 2
                ))
                let pdfData = UIGraphicsPDFRenderer(bounds: bounds).pdfData { ctx in
                    ctx.beginPage()
                    image.draw(in: CGRect(x: marginPoints, y: marginPoints, width: imgSize.width, height: imgSize.height))
                }
                if let tempDoc = PDFDocument(data: pdfData), let page = tempDoc.page(at: 0) {
                    doc.insert(page, at: doc.pageCount)
                }
            case .a4, .letter:
                let bounds = pageSize == .a4
                    ? CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
                    : CGRect(x: 0, y: 0, width: 612, height: 792)
                let availW = max(1, bounds.width - marginPoints * 2)
                let availH = max(1, bounds.height - marginPoints * 2)
                let ratio = min(availW / max(1, image.size.width), availH / max(1, image.size.height))
                let drawW = image.size.width * ratio
                let drawH = image.size.height * ratio
                let drawRect = CGRect(
                    x: (bounds.width - drawW) / 2,
                    y: (bounds.height - drawH) / 2,
                    width: drawW,
                    height: drawH
                )
                let pdfData = UIGraphicsPDFRenderer(bounds: bounds).pdfData { ctx in
                    ctx.beginPage()
                    UIColor.white.setFill()
                    ctx.fill(bounds)
                    image.draw(in: drawRect)
                }
                if let tempDoc = PDFDocument(data: pdfData), let page = tempDoc.page(at: 0) {
                    doc.insert(page, at: doc.pageCount)
                }
            }
        }

        guard doc.pageCount > 0 else { throw PDFServiceError.writeFailed }
        guard doc.write(to: outputURL) else { throw PDFServiceError.writeFailed }
        return outputURL
    }

    // MARK: - Password Protection (Local PDFKit Encryption)

    func protect(
        url: URL,
        userPassword: String,
        ownerPassword: String? = nil,
        outputName: String = "protected.pdf"
    ) throws -> URL {
        guard let doc = PDFDocument(url: url), doc.pageCount > 0 else {
            throw PDFServiceError.invalidPDF
        }
        guard !userPassword.isEmpty else {
            throw PDFServiceError.invalidInput
        }
        let outputURL = fileManager.documentsURL(for: outputName)
        let effectiveOwner = (ownerPassword?.isEmpty == false) ? ownerPassword! : userPassword
        let options: [PDFDocumentWriteOption: Any] = [
            .userPasswordOption: userPassword,
            .ownerPasswordOption: effectiveOwner,
        ]
        guard doc.write(to: outputURL, withOptions: options) else {
            throw PDFServiceError.writeFailed
        }
        return outputURL
    }

    // MARK: - Watermark (Local CoreGraphics Vector PDF Composition)

    func watermark(
        url: URL,
        options: PDFWatermarkOptions,
        outputName: String = "watermarked.pdf"
    ) throws -> URL {
        guard let doc = PDFDocument(url: url), doc.pageCount > 0 else {
            throw PDFServiceError.invalidPDF
        }
        let targetSet: Set<Int>
        if let pageNumbers = options.pageNumbers, !pageNumbers.isEmpty {
            targetSet = Set(pageNumbers.filter { $0 >= 1 && $0 <= doc.pageCount })
        } else {
            targetSet = Set(1...doc.pageCount)
        }
        guard !targetSet.isEmpty else { throw PDFServiceError.invalidPageSelection }

        let outputURL = fileManager.documentsURL(for: outputName)
        let firstBounds = doc.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: firstBounds)

        let data = renderer.pdfData { ctx in
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                let pageBounds = page.bounds(for: .mediaBox)
                ctx.beginPage(withBounds: pageBounds, pageInfo: [:])
                let cg = ctx.cgContext

                // Draw original PDF page in PDF coordinate space
                cg.saveGState()
                cg.translateBy(x: 0, y: pageBounds.height)
                cg.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: cg)
                cg.restoreGState()

                let pageNo = i + 1
                guard targetSet.contains(pageNo) else { continue }

                // Draw watermark in UIKit top-left coordinates
                cg.saveGState()
                cg.setAlpha(max(0.05, min(1.0, options.opacity)))

                let anchor = watermarkCenterPoint(in: pageBounds, position: options.position)
                cg.translateBy(x: anchor.x, y: anchor.y)
                cg.rotate(by: options.rotationDegrees * .pi / 180.0)

                switch options.content {
                case .text(let rawText, let color, let fontSizeRatio):
                    let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { break }
                    let fontSize = max(14, min(pageBounds.width, pageBounds.height) * fontSizeRatio)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                        .foregroundColor: color,
                    ]
                    let nsText = NSString(string: text)
                    let textSize = nsText.size(withAttributes: attrs)
                    nsText.draw(
                        at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2),
                        withAttributes: attrs
                    )

                case .image(let img):
                    let maxW = pageBounds.width * 0.45
                    let aspect = img.size.height / max(1, img.size.width)
                    let drawW = min(maxW, img.size.width)
                    let drawH = drawW * aspect
                    img.draw(in: CGRect(x: -drawW / 2, y: -drawH / 2, width: drawW, height: drawH))
                }

                cg.restoreGState()
            }
        }

        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private func watermarkCenterPoint(in rect: CGRect, position: PDFWatermarkPosition) -> CGPoint {
        switch position {
        case .center:
            return CGPoint(x: rect.width * 0.5, y: rect.height * 0.5)
        case .topLeft:
            return CGPoint(x: rect.width * 0.22, y: rect.height * 0.16)
        case .topRight:
            return CGPoint(x: rect.width * 0.78, y: rect.height * 0.16)
        case .bottomLeft:
            return CGPoint(x: rect.width * 0.22, y: rect.height * 0.84)
        case .bottomRight:
            return CGPoint(x: rect.width * 0.78, y: rect.height * 0.84)
        }
    }

    // MARK: - Signature

    /// Embed a hand-drawn or typed signature into a PDF page and export a signed PDF.
    /// `bounds` is in UIKit top-left coordinates within the page's mediaBox dimensions.
    func sign(
        url: URL,
        signatureImage: UIImage,
        bounds: CGRect,
        pageIndex: Int = 0,
        outputName: String = "signed.pdf"
    ) throws -> URL {
        guard let doc = PDFDocument(url: url),
              pageIndex >= 0,
              pageIndex < doc.pageCount else { throw PDFServiceError.invalidPDF }

        let outputURL = fileManager.documentsURL(for: outputName)
        let firstBounds = doc.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: firstBounds)

        let data = renderer.pdfData { ctx in
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                let pageRect = page.bounds(for: .mediaBox)
                ctx.beginPage(withBounds: pageRect, pageInfo: [:])
                let cg = ctx.cgContext

                cg.saveGState()
                cg.translateBy(x: 0, y: pageRect.height)
                cg.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: cg)
                cg.restoreGState()

                if i == pageIndex {
                    signatureImage.draw(in: bounds)
                }
            }
        }

        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }
}

enum PDFServiceError: LocalizedError, Sendable, Equatable {
    case invalidPDF
    case writeFailed
    case invalidInput
    case invalidPageSelection

    var errorDescription: String? {
        switch self {
        case .invalidPDF: return "The PDF file could not be opened or is password-protected."
        case .writeFailed: return "Failed to save the output PDF file."
        case .invalidInput: return "Please provide valid input parameters."
        case .invalidPageSelection: return "No valid pages matched your selection."
        }
    }
}
