// xcode: set sdk=iOS

import XCTest
import PDFKit
import UIKit
import ImageIO
@testable import Perkakasku

@MainActor
final class PerkakaskuTests: XCTestCase {

    // MARK: - 1. Tool Registry & SF Symbols Audit (All 21 Tools)

    func testToolRegistryHas21ToolsAndUniqueSlugs() {
        XCTAssertEqual(ToolRegistry.all.count, 21, "Expected 21 registered tools")
        let slugs = Set(ToolRegistry.all.map(\.slug))
        XCTAssertEqual(slugs.count, 21, "Every tool slug must be unique")
    }

    func testToolCategoriesAndPopularSlugs() {
        let cats = Set(ToolRegistry.all.map(\.category))
        XCTAssertEqual(cats.count, ToolCategory.allCases.count)
        XCTAssertEqual(ToolRegistryService.shared.tools(in: .pdf).count, 10)
        XCTAssertEqual(ToolRegistryService.shared.tools(in: .image).count, 6)
        XCTAssertEqual(ToolRegistryService.shared.tools(in: .document).count, 5)
        for slug in ToolRegistry.popularSlugs {
            XCTAssertNotNil(ToolRegistry.tool(slug: slug), "Missing popular slug \(slug)")
        }
    }

    func testEveryToolHasValidSFSymbolAndMetadata() {
        for tool in ToolRegistry.all {
            XCTAssertFalse(tool.name.isEmpty, "Tool \(tool.slug) has empty name")
            XCTAssertFalse(tool.webSlug.isEmpty, "Tool \(tool.slug) has empty webSlug")
            XCTAssertFalse(tool.inputHint.isEmpty, "Tool \(tool.slug) has empty inputHint")
            XCTAssertFalse(tool.privacySummary.isEmpty, "Tool \(tool.slug) has empty privacySummary")
            XCTAssertNotNil(
                UIImage(systemName: tool.iconName),
                "Tool \(tool.slug) uses invalid SF Symbol: \(tool.iconName)"
            )
        }
    }

    // MARK: - 2. Guest Mode & State Services

    func testAuthServiceDefaultsToGuestSession() {
        let auth = AuthService.shared
        XCTAssertTrue(auth.isGuestSession)
        XCTAssertFalse(auth.guestIdentifier.isEmpty)
        XCTAssertFalse(auth.effectiveDisplayName.isEmpty)
    }

    func testFavoritesTogglePersistence() {
        let favs = FavoritesService.shared
        let testSlug = "qr-code"
        let initiallyFav = favs.isFavorite(testSlug)
        favs.toggle(testSlug)
        XCTAssertEqual(favs.isFavorite(testSlug), !initiallyFav)
        favs.toggle(testSlug)
        XCTAssertEqual(favs.isFavorite(testSlug), initiallyFav)
    }

    // MARK: - 3. String, Word Counter, JSON Formatter & Diff

    func testWordCounterMetrics() {
        let sample = "Hello world.\n\nSecond paragraph has four words!"
        XCTAssertEqual(sample.wordCount, 7)
        XCTAssertEqual(sample.paragraphCount, 2)
        XCTAssertEqual(sample.sentenceCount, 2)
        XCTAssertEqual(sample.estimatedReadingMinutes, 1)
        XCTAssertEqual("".wordCount, 0)
    }

    func testJSONFormatterMinifierValidatorAndDiff() throws {
        let raw = #"{"b":2,"a":{"z":1}}"#
        let pretty = try raw.processJSON(indent: 2, sortKeys: true, minify: false)
        XCTAssertTrue(pretty.output.contains("\n"))
        XCTAssertEqual(pretty.stats.keyCount, 3)
        XCTAssertEqual(pretty.stats.depth, 3)

        let minified = try raw.processJSON(indent: 2, sortKeys: true, minify: true)
        XCTAssertFalse(minified.output.contains("\n"))

        XCTAssertThrowsError(try "{broken".processJSON())

        let diff = String.computeLineDiff(left: "a\nb", right: "a\nc")
        XCTAssertTrue(diff.contains { $0.kind == .remove && $0.text == "b" })
        XCTAssertTrue(diff.contains { $0.kind == .add && $0.text == "c" })
    }

    func testAll21ToolWorkspacesMountAndHistoryRecordsCleanly() {
        for tool in ToolRegistry.all {
            let view = ToolWorkspaceRouter.workspace(for: tool)
            XCTAssertNotNil(view, "Router failed for tool \(tool.slug)")
        }

        let initialCount = HistoryService.shared.totalProcessedCount
        if let sampleTool = ToolRegistry.tool(slug: "qr-code") {
            HistoryService.shared.record(
                tool: sampleTool,
                inputFileName: "unit-test-qr",
                outputFileName: "unit-test-qr.png",
                status: .completed,
                fileSize: 1024
            )
            XCTAssertGreaterThanOrEqual(HistoryService.shared.totalProcessedCount, initialCount + 1)
            if let inserted = HistoryService.shared.items.first(where: { $0.inputFileName == "unit-test-qr" }) {
                HistoryService.shared.delete(inserted)
            }
        }
    }

    // MARK: - 4. PDFKit Processing (Merge, Split, Range, Images, Encrypt, Watermark, Sign)

    func testPDFSuiteEndToEnd() throws {
        let pdfService = PDFService.shared
        let pdf1 = try makeSamplePDF(name: "sample1.pdf", pages: ["Page One Alpha", "Page Two Beta"])
        let pdf2 = try makeSamplePDF(name: "sample2.pdf", pages: ["Page Three Gamma"])

        XCTAssertEqual(pdfService.pageCount(url: pdf1), 2)
        XCTAssertEqual(pdfService.parsePageRanges("1, 2-3, 9", maxPage: 3), [1, 2, 3])

        // Merge
        let merged = try pdfService.merge(urls: [pdf1, pdf2], outputName: "test_merged.pdf")
        XCTAssertEqual(pdfService.pageCount(url: merged), 3)

        // Split all & extract range
        let splits = try pdfService.split(url: merged, outputPrefix: "test_split")
        XCTAssertEqual(splits.count, 3)

        let extracted = try pdfService.extractCombinedRange(url: merged, pages: [1, 3], outputName: "test_extract.pdf")
        XCTAssertEqual(pdfService.pageCount(url: extracted), 2)

        // Local compress
        let (compressed, pages) = try pdfService.compressLocally(url: merged, outputName: "test_comp.pdf")
        XCTAssertEqual(pages, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: compressed.path))

        // PDF -> Images
        let renderedImages = pdfService.pdfToImages(url: merged, dpi: 100)
        XCTAssertEqual(renderedImages.count, 3)

        // Images -> PDF
        let rebuiltPDF = try pdfService.imagesToPDF(images: renderedImages, pageSize: .a4, marginPoints: 12, outputName: "test_img2pdf.pdf")
        XCTAssertEqual(pdfService.pageCount(url: rebuiltPDF), 3)

        // Password Protect
        let locked = try pdfService.protect(url: pdf1, userPassword: "secret42", outputName: "test_locked.pdf")
        let lockedDoc = PDFDocument(url: locked)
        XCTAssertNotNil(lockedDoc)
        XCTAssertTrue(lockedDoc?.isEncrypted ?? false)
        XCTAssertTrue(lockedDoc?.unlock(withPassword: "secret42") ?? false)

        // Watermark
        let wmOpts = PDFWatermarkOptions(
            content: .text("CONFIDENTIAL", color: .red, fontSizeRatio: 0.08),
            position: .center,
            opacity: 0.35,
            rotationDegrees: -30,
            pageNumbers: [1]
        )
        let watermarked = try pdfService.watermark(url: pdf1, options: wmOpts, outputName: "test_wm.pdf")
        XCTAssertEqual(pdfService.pageCount(url: watermarked), 2)

        // Signature
        let sigImg = makeTextImage(text: "Signed By Test", size: CGSize(width: 260, height: 90))
        let signed = try pdfService.sign(
            url: pdf1,
            signatureImage: sigImg,
            bounds: CGRect(x: 320, y: 680, width: 180, height: 64),
            pageIndex: 0,
            outputName: "test_signed.pdf"
        )
        XCTAssertEqual(pdfService.pageCount(url: signed), 2)
    }

    // MARK: - 5. Image Studio (Compress, Resize, Crop, Rotate, HEIC, 300 DPI Passport, QR PNG+SVG)

    func testImageStudioAndQREndToEnd() throws {
        let imageService = ImageService.shared
        let src = makeSamplePhoto(size: CGSize(width: 600, height: 400))

        // Compress JPG
        let jpgData = imageService.compress(image: src, quality: 0.55)
        XCTAssertNotNil(jpgData)

        // Resize
        let resized = imageService.resize(image: src, to: CGSize(width: 300, height: 200))
        XCTAssertEqual(Int(resized?.size.width ?? 0), 300)
        XCTAssertEqual(Int(resized?.size.height ?? 0), 200)

        // Crop & Rotate
        let cropped = imageService.crop(image: src, to: CGRect(x: 50, y: 50, width: 200, height: 200))
        XCTAssertEqual(Int(cropped?.size.width ?? 0), 200)
        let rotated = imageService.rotate90(src)
        XCTAssertEqual(Int(rotated.size.width), 400)
        XCTAssertEqual(Int(rotated.size.height), 600)

        // HEIC encode & decode to JPG
        let heicData = imageService.convert(image: src, to: .heic(quality: 0.85))
        XCTAssertNotNil(heicData)
        if let heicData {
            let convertedJPG = imageService.heicToJPG(data: heicData, quality: 0.9, stripMetadata: true)
            XCTAssertNotNil(convertedJPG)
        }

        // Passport Photo 300 DPI
        let passport = imageService.renderPassportPhoto(
            image: src,
            preset: .size3x4,
            backgroundColor: .red,
            dpi: 300
        )
        XCTAssertNotNil(passport)
        if let passport {
            XCTAssertEqual(Int(passport.image.size.width), 354)
            XCTAssertEqual(Int(passport.image.size.height), 472)
            let imgSource = CGImageSourceCreateWithData(passport.data as CFData, nil)
            let props = imgSource.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
            XCTAssertEqual(props?[kCGImagePropertyDPIWidth] as? Int, 300)
            XCTAssertEqual(props?[kCGImagePropertyDPIHeight] as? Int, 300)
        }

        // QR Code PNG & SVG
        let qrImg = imageService.generateQRCode(from: "https://perkakasku.cloud", size: CGSize(width: 512, height: 512))
        XCTAssertNotNil(qrImg)
        let svg = imageService.generateQRCodeSVG(from: "https://perkakasku.cloud")
        XCTAssertTrue(svg?.contains("<svg") == true)
        XCTAssertTrue(svg?.contains("<rect") == true)
    }

    // MARK: - 6. Apple Vision OCR & Foreground Segmentation

    func testVisionOCRRecognizesText() async throws {
        let img = makeTextImage(text: "PERKAKASKU STUDIO", size: CGSize(width: 800, height: 220))
        let result = try await VisionOCRService.shared.recognizeImage(
            img,
            language: .english,
            enhanceContrast: true
        )
        XCTAssertTrue(result.text.localizedCaseInsensitiveContains("PERKAKASKU"))
    }

    func testVisionSegmentationHandlesSubject() async throws {
        let img = makeSubjectOnWhiteBackdrop(size: CGSize(width: 320, height: 320))
        let result = try await VisionSegmentationService.shared.removeBackground(from: img)
        XCTAssertFalse(result.pngData.isEmpty)
        XCTAssertEqual(Int(result.cutoutImage.size.width), 320)
    }

    // MARK: - 7. ZIPBuilder Archive Validity

    func testZIPBuilderArchive() throws {
        let archive = try ZIPBuilder.buildArchive(entries: [
            ZIPBuilder.Entry(fileName: "hello.txt", data: Data("world".utf8)),
            ZIPBuilder.Entry(fileName: "meta.json", data: Data("{}".utf8)),
        ])
        XCTAssertGreaterThan(archive.count, 30)
        XCTAssertEqual(Array(archive.prefix(4)), [0x50, 0x4B, 0x03, 0x04]) // PK\x03\x04
    }

    // MARK: - 8. Docker Backend API Integration & Network Failure Tests

    func testDockerBackendIntegrationAndAllServerEndpoints() async throws {
        let prevOverride = APIConfig.customURLOverride
        let prevEnv = APIConfig.environment
        defer {
            APIConfig.environment = prevEnv
            APIConfig.customURLOverride = prevOverride
        }

        APIConfig.customURLOverride = nil
        APIConfig.environment = .development

        // Health, Capabilities & Public Plans
        let (health, _) = try await APIService.shared.checkHealth()
        XCTAssertEqual(health.status, "ok")
        XCTAssertEqual(health.db, "connected")

        let caps = try await APIService.shared.capabilities()
        XCTAssertNotNil(caps)

        let plans = try await APIService.shared.fetchPublicPlans()
        XCTAssertGreaterThanOrEqual(plans.count, 1)

        // Generate real PDF for server conversion endpoints
        let pdfURL = try makeSamplePDF(
            name: "server_test.pdf",
            pages: ["Perkakasku Server Integration Test Document\nCol1   Col2\n100    200"]
        )
        let pdfData = try Data(contentsOf: pdfURL)
        let pdfMultipart = MultipartFile(
            fieldName: "file",
            fileName: "server_test.pdf",
            mimeType: "application/pdf",
            data: pdfData
        )

        // /api/tools/pdf-compress
        let compressed = try await APIService.shared.compressPDF(file: pdfMultipart, level: "balanced")
        XCTAssertTrue(compressed.data.starts(with: Data("%PDF".utf8)))

        // /api/tools/pdf-to-word
        let docxOut = try await APIService.shared.pdfToWord(file: pdfMultipart)
        XCTAssertEqual(Array(docxOut.data.prefix(2)), [0x50, 0x4B]) // ZIP/DOCX magic bytes

        // /api/tools/pdf-to-excel
        let xlsxOut = try await APIService.shared.pdfToExcel(file: pdfMultipart, pages: nil, sheetName: "TestSheet")
        XCTAssertEqual(Array(xlsxOut.data.prefix(2)), [0x50, 0x4B]) // ZIP/XLSX magic bytes

        // /api/tools/word-to-pdf (minimal valid .docx built with ZIPBuilder)
        let docxData = try makeMinimalDOCX(text: "Hello from iOS Word to PDF test")
        let docxMultipart = MultipartFile(
            fieldName: "file",
            fileName: "sample.docx",
            mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            data: docxData
        )
        let wordPdfOut = try await APIService.shared.wordToPDF(file: docxMultipart)
        XCTAssertTrue(wordPdfOut.data.starts(with: Data("%PDF".utf8)))

        // /api/tools/passport-photo
        let photo = makeSamplePhoto(size: CGSize(width: 400, height: 500))
        if let jpgData = photo.jpegData(compressionQuality: 0.9) {
            let imgFile = MultipartFile(fieldName: "file", fileName: "face.jpg", mimeType: "image/jpeg", data: jpgData)
            let dpiOut = try await APIService.shared.passportPhoto(file: imgFile, preset: "3x4", dpi: 300)
            XCTAssertGreaterThan(dpiOut.data.count, 100)
        }
    }

    func testNetworkFailureReturnsGracefulAPIError() async {
        let prevOverride = APIConfig.customURLOverride
        defer { APIConfig.customURLOverride = prevOverride }

        APIConfig.customURLOverride = "http://127.0.0.1:59999"
        do {
            _ = try await APIService.shared.checkHealth()
            XCTFail("Expected network failure error for unused port")
        } catch let apiErr as APIError {
            switch apiErr {
            case .networkUnavailable, .timeout, .requestFailed:
                break // Expected graceful mapping
            default:
                XCTFail("Unexpected APIError case: \(apiErr)")
            }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    // MARK: - Helpers

    private func makeSamplePDF(name: String, pages: [String]) throws -> URL {
        let bounds = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { ctx in
            for text in pages {
                ctx.beginPage()
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
                    .foregroundColor: UIColor.black,
                ]
                NSString(string: text).draw(in: CGRect(x: 48, y: 72, width: 500, height: 680), withAttributes: attrs)
            }
        }
        let url = LocalFileManager.shared.documentsURL(for: name)
        try LocalFileManager.shared.write(data: data, to: url)
        return url
    }

    private func makeTextImage(text: String, size: CGSize) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 46, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            NSString(string: text).draw(at: CGPoint(x: 36, y: size.height * 0.35), withAttributes: attrs)
        }
    }

    private func makeSamplePhoto(size: CGSize) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIColor(red: 0.92, green: 0.90, blue: 0.87, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.85, green: 0.27, blue: 0.03, alpha: 1).setFill()
            ctx.fill(CGRect(x: size.width * 0.25, y: size.height * 0.25, width: size.width * 0.5, height: size.height * 0.5))
        }
    }

    private func makeSubjectOnWhiteBackdrop(size: CGSize) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.14, green: 0.22, blue: 0.55, alpha: 1).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: size.width * 0.25, y: size.height * 0.2, width: size.width * 0.5, height: size.height * 0.6))
        }
    }

    private func makeMinimalDOCX(text: String) throws -> Data {
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """
        let rels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
        let docXml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p><w:r><w:t>\(text)</w:t></w:r></w:p>
          </w:body>
        </w:document>
        """
        return try ZIPBuilder.buildArchive(entries: [
            ZIPBuilder.Entry(fileName: "[Content_Types].xml", data: Data(contentTypes.utf8)),
            ZIPBuilder.Entry(fileName: "_rels/.rels", data: Data(rels.utf8)),
            ZIPBuilder.Entry(fileName: "word/document.xml", data: Data(docXml.utf8)),
        ])
    }
}
