import Foundation
import UniformTypeIdentifiers
import UIKit

enum FileServiceError: LocalizedError, Sendable {
    case emptyFile
    case fileTooLarge(Int)

    var errorDescription: String? {
        switch self {
        case .emptyFile: return "The selected file is empty (0 bytes)."
        case .fileTooLarge(let mb): return "File exceeds the maximum allowed size of \(mb) MB."
        }
    }
}

/// File import / export helpers bridging UIKit document pickers with SwiftUI.
@MainActor
final class FileService: ObservableObject {
    static let shared = FileService()

    private let fileManager = LocalFileManager.shared

    @Published var importedURLs: [URL] = []
    @Published var exportURL: URL?
    @Published var isExporting = false

    private init() {}

    /// Import a file from a security-scoped URL into sandboxed cache.
    func importFile(at url: URL, preferredName: String? = nil) throws -> URL {
        try fileManager.importFile(from: url, fileName: preferredName)
    }

    /// Determine the MIME type for a file URL.
    func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic", "heif": return "image/heic"
        case "webp": return "image/webp"
        case "tiff", "tif": return "image/tiff"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "doc": return "application/msword"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "json": return "application/json"
        case "txt": return "text/plain"
        case "svg": return "image/svg+xml"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }

    /// Build a MultipartFile from a local or security-scoped file URL.
    func multipartFile(from url: URL, fieldName: String = "file", maxFileSizeMB: Int? = nil) throws -> MultipartFile {
        let data = try fileManager.read(from: url)
        guard !data.isEmpty else {
            throw FileServiceError.emptyFile
        }
        if let maxMB = maxFileSizeMB, maxMB > 0, data.count > maxMB * 1024 * 1024 {
            throw FileServiceError.fileTooLarge(maxMB)
        }
        return MultipartFile(
            fieldName: fieldName,
            fileName: url.lastPathComponent,
            mimeType: mimeType(for: url),
            data: data
        )
    }

    func supports(uti: String, for tool: Tool) -> Bool {
        guard !tool.acceptedUTIs.isEmpty else { return true }
        return tool.acceptedUTIs.contains(uti)
    }

    func uti(forExtension ext: String) -> String {
        let clean = ext.lowercased().replacingOccurrences(of: ".", with: "")
        switch clean {
        case "pdf": return UTType.pdf.identifier
        case "jpg", "jpeg": return UTType.jpeg.identifier
        case "png": return UTType.png.identifier
        case "heic": return UTType.heic.identifier
        case "heif": return UTType.heif.identifier
        case "tiff", "tif": return UTType.tiff.identifier
        case "docx": return UTType("org.openxmlformats.wordprocessingml.document")?.identifier ?? clean
        case "xlsx": return UTType("org.openxmlformats.spreadsheetml.sheet")?.identifier ?? clean
        case "json": return UTType.json.identifier
        case "txt": return UTType.plainText.identifier
        default: return clean
        }
    }
}
