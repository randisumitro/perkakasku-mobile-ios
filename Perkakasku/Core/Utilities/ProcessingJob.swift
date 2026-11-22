import Foundation
import SwiftUI

/// A processing job tracked through the UI pipeline.
@MainActor
final class ProcessingJob: ObservableObject {
    let id: UUID
    let toolSlug: String
    let toolName: String
    let category: ToolCategory
    let inputURL: URL

    @Published var status: ProcessingStatus = .pending
    @Published var progress: Double = 0
    @Published var outputURL: URL?
    @Published var error: String?

    init(toolSlug: String, toolName: String, category: ToolCategory, inputURL: URL) {
        self.id = UUID()
        self.toolSlug = toolSlug
        self.toolName = toolName
        self.category = category
        self.inputURL = inputURL
    }
}

/// Manages reading/writing files in the app's Documents and Caches directories,
/// including proper iOS security-scoped file access for imported URLs.
final class LocalFileManager: Sendable {
    static let shared = LocalFileManager()
    private nonisolated(unsafe) let fileManager = FileManager.default

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var cachesURL: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    var outputsDirectoryURL: URL {
        let dir = documentsURL.appendingPathComponent("PerkakaskuOutputs", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {}

    /// URL for a file in the Documents outputs directory (avoids overwriting previous results cleanly).
    func documentsURL(for fileName: String) -> URL {
        let cleanName = sanitizedFileName(fileName)
        return uniqueURL(for: outputsDirectoryURL.appendingPathComponent(cleanName))
    }

    /// URL for a temporary file in Caches.
    func cacheURL(for fileName: String) -> URL {
        cachesURL.appendingPathComponent(sanitizedFileName(fileName))
    }

    /// Write Data to a file, returning its URL.
    func write(data: Data, to url: URL) throws {
        let parent = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        try data.write(to: url, options: .atomic)
    }

    /// Read Data from a file URL.
    func read(from url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        return try Data(contentsOf: url)
    }

    /// Delete a file if it exists.
    func delete(at url: URL) {
        try? fileManager.removeItem(at: url)
    }

    /// Copy an imported file (handling iOS security-scoped URLs) into the app's sandboxed cache/documents.
    func importFile(from url: URL, fileName: String? = nil) throws -> URL {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        let name = sanitizedFileName(fileName ?? url.lastPathComponent)
        let importsDir = cachesURL.appendingPathComponent("PerkakaskuImports", isDirectory: true)
        if !fileManager.fileExists(atPath: importsDir.path) {
            try fileManager.createDirectory(at: importsDir, withIntermediateDirectories: true)
        }
        let dest = uniqueURL(for: importsDir.appendingPathComponent(name))
        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
        try fileManager.copyItem(at: url, to: dest)
        return dest
    }

    /// Calculate total size in bytes of locally stored output files.
    func totalOutputsStorageBytes() -> Int64 {
        guard let items = try? fileManager.contentsOfDirectory(
            at: outputsDirectoryURL,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return items.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + Int64(size)
        }
    }

    /// Remove all cached output & import files.
    func clearOutputsCache() {
        for dir in [outputsDirectoryURL, cachesURL.appendingPathComponent("PerkakaskuImports", isDirectory: true)] {
            if let items = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for url in items {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
    }

    /// Ensure a unique path by appending a counter before the extension.
    func uniqueURL(for url: URL) -> URL {
        var candidate = url
        var counter = 1
        while fileManager.fileExists(atPath: candidate.path) {
            let ext = url.pathExtension
            let base = url.deletingPathExtension().lastPathComponent
            let dir = url.deletingLastPathComponent()
            let nextName = ext.isEmpty ? "\(base)_\(counter)" : "\(base)_\(counter).\(ext)"
            candidate = dir.appendingPathComponent(nextName)
            counter += 1
        }
        return candidate
    }

    func sanitizedFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return safe.isEmpty ? "file" : safe
    }

    /// UTI for a file URL based on its extension.
    func uti(for url: URL) -> String {
        url.pathExtension.lowercased()
    }
}
