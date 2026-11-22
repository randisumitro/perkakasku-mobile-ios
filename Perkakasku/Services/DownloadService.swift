import Foundation
import UniformTypeIdentifiers
import UIKit

/// Downloads processed output from the server and stores it locally.
final class DownloadService: Sendable {
    static let shared = DownloadService()

    private let client = APIClient.shared
    private let fileManager = LocalFileManager.shared

    private init() {}

    /// Download the bytes at `outputURL` (a server-relative path or full URL)
    /// and store them in the app's Documents directory.
    func download(outputPath: String, fileName: String) async throws -> URL {
        let url: URL
        if outputPath.hasPrefix("http") {
            url = URL(string: outputPath)!
        } else {
            url = APIConfig.baseURL.appendingPathComponent(outputPath)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, _) = try await client.getRaw(url: url)
        let dest = fileManager.documentsURL(for: fileName)
        try data.write(to: dest, options: .atomic)
        return dest
    }
}
