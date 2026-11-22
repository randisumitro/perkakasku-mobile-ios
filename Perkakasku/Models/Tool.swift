import Foundation

/// Category of a tool, used for filtering and sectioning the catalog.
enum ToolCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case pdf = "pdf"
    case image = "image"
    case document = "document"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pdf: return "PDF Suite"
        case .image: return "Image & Photo AI"
        case .document: return "Document & Utility"
        }
    }

    var shortName: String {
        switch self {
        case .pdf: return "PDF"
        case .image: return "Images"
        case .document: return "Docs & Utils"
        }
    }

    var systemIcon: String {
        switch self {
        case .pdf: return "doc.richtext.fill"
        case .image: return "photo.on.rectangle.angled"
        case .document: return "doc.text.magnifyingglass"
        }
    }

    var tagline: String {
        switch self {
        case .pdf: return "Compress, merge, split, sign, protect & convert"
        case .image: return "AI cutout, 300 DPI ID photo, crop, resize & HEIC"
        case .document: return "Vision OCR, Word to PDF, QR studio, JSON & word stats"
        }
    }
}

/// Where a tool's processing happens.
enum ProcessingMode: String, Codable, Sendable {
    case local = "local"
    case hybrid = "hybrid"
    case server = "server"

    var displayLabel: String {
        switch self {
        case .local: return "On-Device"
        case .hybrid: return "Hybrid"
        case .server: return "Server Sandbox"
        }
    }
}

/// A single tool entry from the authoritative registry.
struct Tool: Identifiable, Sendable, Codable, Hashable {
    let slug: String
    var id: String { slug }
    let webSlug: String
    let name: String
    let category: ToolCategory
    let toolDescription: String
    let iconName: String        // Valid SF Symbol name
    let mode: ProcessingMode
    let supportsMultipleFiles: Bool
    let acceptedUTIs: [String]  // Uniform Type Identifiers for import
    let inputHint: String
    let privacySummary: String
    let maxFileSizeMB: Int?
    let isPremium: Bool
    let isFeatured: Bool
    let relatedSlugs: [String]

    enum CodingKeys: String, CodingKey {
        case slug, webSlug, name, category
        case toolDescription = "description"
        case iconName, mode, supportsMultipleFiles, acceptedUTIs
        case inputHint, privacySummary, maxFileSizeMB, isPremium, isFeatured, relatedSlugs
    }

    var isLocalOnly: Bool { mode == .local }
}

/// The authoritative tool catalog, mirroring the web platform's 21 tools.
/// Every one of the 21 registered tools has a real mobile workflow.
struct ToolRegistry {
    static let all: [Tool] = [
        // MARK: - PDF Suite (10)
        Tool(
            slug: "pdf-compress",
            webSlug: "kompres-pdf",
            name: "Compress PDF",
            category: .pdf,
            toolDescription: "Reduce PDF file size with Low, Balanced, or High profiles while preserving readability.",
            iconName: "doc.zipper",
            mode: .hybrid,
            supportsMultipleFiles: false,
            acceptedUTIs: ["com.adobe.pdf"],
            inputHint: "PDF document",
            privacySummary: "Processed in an isolated temporary server directory and deleted immediately after download, with automatic local PDFKit fallback offline.",
            maxFileSizeMB: 50,
            isPremium: false,
            isFeatured: true,
            relatedSlugs: ["pdf-merge", "pdf-split", "pdf-to-word"]
        ),
        Tool(
            slug: "pdf-merge",
            webSlug: "gabung-pdf",
            name: "Merge PDF",
            category: .pdf,
            toolDescription: "Combine multiple PDF files into one clean document with drag-and-drop page ordering.",
            iconName: "doc.on.doc.fill",
            mode: .local,
            supportsMultipleFiles: true,
            acceptedUTIs: ["com.adobe.pdf"],
            inputHint: "Multiple PDF files",
            privacySummary: "All PDF files are merged 100% locally in memory on your iPhone using PDFKit. Nothing leaves your device.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: true,
            relatedSlugs: ["pdf-split", "pdf-compress", "image-to-pdf"]
        ),
        Tool(
            slug: "pdf-split",
            webSlug: "pisah-pdf",
            name: "Split PDF",
            category: .pdf,
            toolDescription: "Extract specific page ranges or split every PDF page into individual files or a ZIP bundle.",
            iconName: "scissors",
            mode: .local,
            supportsMultipleFiles: false,
            acceptedUTIs: ["com.adobe.pdf"],
            inputHint: "Single PDF document",
            privacySummary: "Page extraction runs entirely on-device using Apple PDFKit without uploading files.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: false,
            relatedSlugs: ["pdf-merge", "pdf-to-image", "pdf-compress"]
        ),
        Tool(
            slug: "pdf-to-image",
            webSlug: "pdf-to-image",
            name: "PDF to Image",
            category: .pdf,
            toolDescription: "Render PDF pages into crisp PNG or JPG images with selectable 72, 150, or 300 DPI resolution.",
            iconName: "photo.on.rectangle.angled",
            mode: .local,
            supportsMultipleFiles: false,
            acceptedUTIs: ["com.adobe.pdf"],
            inputHint: "PDF document",
            privacySummary: "Pages are rendered directly on your device via CoreGraphics and PDFKit with selectable DPI and ZIP export.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: false,
            relatedSlugs: ["image-to-pdf", "pdf-split", "ocr"]
        ),
        Tool(
            slug: "pdf-to-excel",
            webSlug: "pdf-to-excel",
            name: "PDF to Excel",
            category: .pdf,
            toolDescription: "Extract selectable text and multi-column tables from PDF pages into an .xlsx spreadsheet.",
            iconName: "tablecells.fill",
            mode: .server,
            supportsMultipleFiles: false,
            acceptedUTIs: ["com.adobe.pdf"],
            inputHint: "Text-based PDF",
            privacySummary: "Table extraction runs in an isolated sandbox container and temporary files are wiped immediately after returning your XLSX.",
            maxFileSizeMB: 50,
            isPremium: false,
            isFeatured: false,
            relatedSlugs: ["pdf-to-word", "ocr", "pdf-to-image"]
        ),
        Tool(
            slug: "pdf-to-word",
            webSlug: "pdf-ke-word",
            name: "PDF to Word",
            category: .pdf,
            toolDescription: "Convert PDF paragraphs, headings, and tables into an editable Microsoft Word (.docx) document.",
            iconName: "doc.richtext.fill",
            mode: .server,
            supportsMultipleFiles: false,
            acceptedUTIs: ["com.adobe.pdf"],
            inputHint: "PDF document",
            privacySummary: "Converted in an isolated server sandbox and deleted immediately after transmission; scanned PDFs are detected automatically.",
            maxFileSizeMB: 50,
            isPremium: false,
            isFeatured: true,
            relatedSlugs: ["word-to-pdf", "ocr", "pdf-compress"]
        ),
        Tool(
            slug: "pdf-signature",
            webSlug: "pdf-signature",
            name: "PDF Signature",
            category: .pdf,
            toolDescription: "Draw with PencilKit, type, or import a signature and place it accurately on any PDF page.",
            iconName: "signature",
            mode: .local,
            supportsMultipleFiles: false,
            acceptedUTIs: ["com.adobe.pdf"],
            inputHint: "PDF + hand-drawn or typed signature",
            privacySummary: "Signatures are composited locally on-device using Apple PencilKit and PDFKit. Your documents never leave your iPhone.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: false,
            relatedSlugs: ["pdf-watermark", "pdf-password", "pdf-compress"]
        ),
        Tool(
            slug: "pdf-password",
            webSlug: "pdf-password",
            name: "PDF Password Protection",
            category: .pdf,
            toolDescription: "Encrypt a PDF locally with user and owner passwords to lock document access and permissions.",
            iconName: "lock.doc.fill",
            mode: .local,
            supportsMultipleFiles: false,
            acceptedUTIs: ["com.adobe.pdf"],
            inputHint: "PDF + password",
            privacySummary: "PDF encryption happens 100% locally on your device via PDFKit. Passwords are never transmitted anywhere.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: false,
            relatedSlugs: ["pdf-watermark", "pdf-signature", "pdf-compress"]
        ),
        Tool(
            slug: "pdf-watermark",
            webSlug: "pdf-watermark",
            name: "PDF Watermark",
            category: .pdf,
            toolDescription: "Stamp custom text or image watermarks onto PDF pages with position, opacity, and rotation controls.",
            iconName: "seal.fill",
            mode: .local,
            supportsMultipleFiles: false,
            acceptedUTIs: ["com.adobe.pdf"],
            inputHint: "PDF + watermark text or image",
            privacySummary: "Watermarks are drawn locally onto PDF pages using CoreGraphics and PDFKit with zero server upload.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: false,
            relatedSlugs: ["pdf-signature", "pdf-password", "pdf-compress"]
        ),
        Tool(
            slug: "image-to-pdf",
            webSlug: "gambar-ke-pdf",
            name: "Image to PDF",
            category: .pdf,
            toolDescription: "Bundle multiple photos or scans into a single cleanly formatted PDF document.",
            iconName: "photo.stack.fill",
            mode: .local,
            supportsMultipleFiles: true,
            acceptedUTIs: ["public.jpeg", "public.png", "public.heic"],
            inputHint: "JPG, PNG, or HEIC images",
            privacySummary: "Assembled 100% locally on your device using PDFKit with customizable page sizing and margins.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: false,
            relatedSlugs: ["pdf-merge", "pdf-compress", "heic-to-jpg"]
        ),

        // MARK: - Image & Photo AI Suite (6)
        Tool(
            slug: "image-compress",
            webSlug: "kompres-gambar",
            name: "Compress Image",
            category: .image,
            toolDescription: "Shrink JPG, PNG, or HEIC photo file sizes with adjustable compression quality and live byte savings.",
            iconName: "arrow.down.right.and.arrow.up.left",
            mode: .local,
            supportsMultipleFiles: true,
            acceptedUTIs: ["public.jpeg", "public.png", "public.heic", "public.tiff"],
            inputHint: "JPG, PNG, HEIC, or TIFF",
            privacySummary: "Compressed directly in device memory using ImageIO and CoreGraphics with no upload.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: true,
            relatedSlugs: ["image-resize", "heic-to-jpg", "image-crop"]
        ),
        Tool(
            slug: "image-resize",
            webSlug: "resize-konversi",
            name: "Resize & Convert",
            category: .image,
            toolDescription: "Resize pixel dimensions with aspect-ratio lock and convert between JPEG, PNG, and HEIC.",
            iconName: "slider.horizontal.3",
            mode: .local,
            supportsMultipleFiles: false,
            acceptedUTIs: ["public.jpeg", "public.png", "public.heic", "public.tiff"],
            inputHint: "JPG, PNG, HEIC, or TIFF",
            privacySummary: "Resized and encoded 100% locally on-device with automatic white matte for JPEG conversions.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: false,
            relatedSlugs: ["image-compress", "image-crop", "passport-photo"]
        ),
        Tool(
            slug: "background-remove",
            webSlug: "hapus-background",
            name: "Remove Background",
            category: .image,
            toolDescription: "Isolate subjects automatically into transparent PNGs or solid color mattes using on-device Vision AI.",
            iconName: "person.crop.rectangle.stack",
            mode: .local,
            supportsMultipleFiles: false,
            acceptedUTIs: ["public.jpeg", "public.png", "public.heic"],
            inputHint: "JPG, PNG, or HEIC photo",
            privacySummary: "Powered by on-device Apple Vision subject segmentation and CoreImage masking. Photos stay private on your iPhone.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: true,
            relatedSlugs: ["passport-photo", "image-crop", "image-compress"]
        ),
        Tool(
            slug: "passport-photo",
            webSlug: "pas-foto",
            name: "Passport Photo Maker",
            category: .image,
            toolDescription: "Create 2×3, 3×4, and 4×6 cm ID photos at 300 DPI with framing guides, AI cutout, and Red/Blue/White backgrounds.",
            iconName: "person.text.rectangle.fill",
            mode: .hybrid,
            supportsMultipleFiles: false,
            acceptedUTIs: ["public.jpeg", "public.png", "public.heic"],
            inputHint: "Portrait photo (JPG, PNG, HEIC)",
            privacySummary: "Cropping, Vision background replacement, and 300 DPI metadata injection run locally on-device, with optional server DPI validation.",
            maxFileSizeMB: 25,
            isPremium: false,
            isFeatured: true,
            relatedSlugs: ["background-remove", "image-crop", "image-compress"]
        ),
        Tool(
            slug: "image-crop",
            webSlug: "image-crop",
            name: "Crop Image",
            category: .image,
            toolDescription: "Interactively pan, zoom, and crop photos to Free, 1:1, 4:3, 3:2, 16:9, 9:16, or 2:3 ratios.",
            iconName: "crop",
            mode: .local,
            supportsMultipleFiles: false,
            acceptedUTIs: ["public.jpeg", "public.png", "public.heic"],
            inputHint: "JPG, PNG, or HEIC photo",
            privacySummary: "Cropped entirely on-device with automatic EXIF orientation normalization.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: false,
            relatedSlugs: ["image-resize", "passport-photo", "image-compress"]
        ),
        Tool(
            slug: "heic-to-jpg",
            webSlug: "heic-to-jpg",
            name: "HEIC to JPG",
            category: .image,
            toolDescription: "Batch-convert iPhone HEIC/HEIF photos to universal JPG with optional GPS & EXIF metadata removal.",
            iconName: "arrow.2.squarepath",
            mode: .hybrid,
            supportsMultipleFiles: true,
            acceptedUTIs: ["public.heic", "public.heif"],
            inputHint: "HEIC / HEIF photos",
            privacySummary: "Converts locally with Apple ImageIO (stripping GPS/EXIF by default), or via the isolated server HEIC engine.",
            maxFileSizeMB: 30,
            isPremium: false,
            isFeatured: false,
            relatedSlugs: ["image-compress", "image-resize", "image-to-pdf"]
        ),

        // MARK: - Document & Utility Suite (5)
        Tool(
            slug: "qr-code",
            webSlug: "qr-code",
            name: "QR Code Generator",
            category: .document,
            toolDescription: "Generate customizable QR codes for URLs, text, vCard contacts, or Wi-Fi and export crisp PNG & SVG.",
            iconName: "qrcode",
            mode: .local,
            supportsMultipleFiles: false,
            acceptedUTIs: [],
            inputHint: "URL, text, vCard, or Wi-Fi",
            privacySummary: "Generated instantaneously on-device with CoreImage. Your links and contact data never leave your phone.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: true,
            relatedSlugs: ["json-format", "word-counter", "image-compress"]
        ),
        Tool(
            slug: "word-counter",
            webSlug: "penghitung-kata",
            name: "Word Counter",
            category: .document,
            toolDescription: "Analyze words, characters, sentences, paragraphs, and reading time in real time with TXT export.",
            iconName: "character.cursor.ibeam",
            mode: .local,
            supportsMultipleFiles: false,
            acceptedUTIs: ["public.plain-text"],
            inputHint: "Typed text or .txt file",
            privacySummary: "All text analytics run instantaneously in memory on your iPhone without network transmission.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: false,
            relatedSlugs: ["ocr", "json-format", "pdf-to-word"]
        ),
        Tool(
            slug: "ocr",
            webSlug: "ocr",
            name: "OCR Text Recognition",
            category: .document,
            toolDescription: "Extract editable text from photos and scanned PDFs in Indonesian & English using Apple Vision.",
            iconName: "doc.text.viewfinder",
            mode: .local,
            supportsMultipleFiles: false,
            acceptedUTIs: ["public.jpeg", "public.png", "public.heic", "public.tiff", "com.adobe.pdf"],
            inputHint: "Photo or scanned PDF",
            privacySummary: "Character recognition runs 100% offline on-device using Apple Vision VNRecognizeTextRequest.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: true,
            relatedSlugs: ["pdf-to-word", "word-counter", "image-to-pdf"]
        ),
        Tool(
            slug: "word-to-pdf",
            webSlug: "word-ke-pdf",
            name: "Word to PDF",
            category: .document,
            toolDescription: "Convert Microsoft Word (.docx) files into clean PDFs with macro protection and inline preview.",
            iconName: "doc.badge.gearshape.fill",
            mode: .server,
            supportsMultipleFiles: false,
            acceptedUTIs: ["org.openxmlformats.wordprocessingml.document"],
            inputHint: "Word (.docx) document",
            privacySummary: "Macro-free OOXML conversion runs inside an isolated server sandbox and files are deleted right after PDF delivery.",
            maxFileSizeMB: 25,
            isPremium: false,
            isFeatured: false,
            relatedSlugs: ["pdf-to-word", "pdf-compress", "pdf-merge"]
        ),
        Tool(
            slug: "json-format",
            webSlug: "json-formatter",
            name: "JSON Formatter & Validator",
            category: .document,
            toolDescription: "Beautify, minify, validate syntax with line/column error tracking, sort keys, and compare diffs.",
            iconName: "curlybraces",
            mode: .local,
            supportsMultipleFiles: false,
            acceptedUTIs: ["public.json", "public.plain-text"],
            inputHint: "JSON text or .json file",
            privacySummary: "Parsed strictly with native JSONSerialization on-device without executing scripts or sending payloads externally.",
            maxFileSizeMB: nil,
            isPremium: false,
            isFeatured: false,
            relatedSlugs: ["word-counter", "qr-code", "ocr"]
        ),
    ]

    static let popularSlugs: [String] = [
        "pdf-compress",
        "background-remove",
        "passport-photo",
        "ocr",
        "pdf-merge",
        "qr-code",
    ]

    /// Tools grouped by category.
    static func byCategory() -> [ToolCategory: [Tool]] {
        Dictionary(grouping: all) { $0.category }
    }

    static func tool(slug: String) -> Tool? {
        all.first { $0.slug == slug || $0.webSlug == slug }
    }
}
