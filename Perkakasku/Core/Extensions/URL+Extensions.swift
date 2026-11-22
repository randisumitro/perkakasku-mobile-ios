import Foundation

extension URL {
    /// Human-readable display name without extension.
    var displayName: String {
        deletingPathExtension().lastPathComponent
    }

    /// File size in bytes, or 0 if unavailable.
    var fileSize: Int64 {
        Int64((try? resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }

    /// Formatted file size (KB / MB).
    var formattedSize: String {
        let bytes = fileSize
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}
