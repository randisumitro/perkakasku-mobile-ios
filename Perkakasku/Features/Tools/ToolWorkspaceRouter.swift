// xcode: set sdk=iOS

import SwiftUI

/// Routes each of the 21 registered tools to its interactive native SwiftUI studio.
@MainActor
enum ToolWorkspaceRouter {
    @ViewBuilder
    static func workspace(for tool: Tool) -> some View {
        switch tool.slug {
        // MARK: - PDF Suite (10)
        case "pdf-compress":
            PDFCompressView(tool: tool)
        case "pdf-merge":
            PDFMergeView(tool: tool)
        case "pdf-split":
            PDFSplitView(tool: tool)
        case "pdf-to-image":
            PDFToImageView(tool: tool)
        case "pdf-to-excel":
            PDFToExcelView(tool: tool)
        case "pdf-to-word":
            PDFToWordView(tool: tool)
        case "pdf-signature":
            PDFSignatureView(tool: tool)
        case "pdf-password":
            PDFPasswordView(tool: tool)
        case "pdf-watermark":
            PDFWatermarkView(tool: tool)
        case "image-to-pdf":
            ImageToPDFView(tool: tool)

        // MARK: - Image Studio (6)
        case "image-compress":
            ImageCompressView(tool: tool)
        case "image-resize":
            ImageResizeView(tool: tool)
        case "background-remove":
            BackgroundRemovalView(tool: tool)
        case "passport-photo":
            PassportPhotoView(tool: tool)
        case "image-crop":
            ImageCropView(tool: tool)
        case "heic-to-jpg":
            HEICToJPGView(tool: tool)

        // MARK: - Documents & Utilities (5)
        case "qr-code":
            QRCodeToolView(tool: tool)
        case "word-counter":
            WordCounterToolView(tool: tool)
        case "ocr":
            OCRToolView(tool: tool)
        case "word-to-pdf":
            WordToPDFToolView(tool: tool)
        case "json-format":
            JSONFormatterToolView(tool: tool)

        default:
            EmptyStateView(
                icon: tool.iconName,
                title: tool.name,
                subtitle: "Workspace unavailable for slug \(tool.slug)."
            )
        }
    }
}
