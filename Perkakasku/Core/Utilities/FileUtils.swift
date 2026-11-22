import Foundation
import UniformTypeIdentifiers
import CoreImage
import UIKit

/// File-type utilities shared across import/export flows.
enum FileUtils {
    /// Accepted UTIs for image import.
    static let imageUTIs: [String] = [
        UTType.jpeg.identifier,
        UTType.png.identifier,
        UTType.heic.identifier,
        UTType.tiff.identifier,
    ]

    static let pdfUTI = UTType.pdf.identifier

    /// Whether a UTI represents an image.
    static func isImage(_ uti: String) -> Bool {
        imageUTIs.contains(uti)
    }

    /// Generate a unique output file name.
    static func outputFileName(input: String, suffix: String, ext: String) -> String {
        let base = (input as NSString).deletingPathExtension
        return "\(base)_\(suffix).\(ext)"
    }

    /// Create a CIImage from a UIImage (for CoreImage filters).
    static func ciImage(from image: UIImage) -> CIImage? {
        guard let cg = image.cgImage else { return nil }
        return CIImage(cgImage: cg)
    }
}
