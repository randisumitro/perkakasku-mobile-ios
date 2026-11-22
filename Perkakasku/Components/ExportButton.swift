import SwiftUI
import UIKit

/// Working share & preview button for any exported file URL.
struct ExportButton: View {
    let fileURL: URL?
    var label: String = "Share / Export"
    var showPreview: Bool = true
    var imageToSave: UIImage? = nil

    @State private var showingPreview = false
    @State private var savedToPhotos = false
    @State private var photoSaveError: String?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if let fileURL {
                    ShareLink(item: fileURL) {
                        Label(label, systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PKPillButtonStyle(variant: .primary))
                    .accessibilityIdentifier("exportShareButton")

                    if showPreview {
                        Button {
                            PKHaptics.impact(.light)
                            showingPreview = true
                        } label: {
                            Label("Preview", systemImage: "eye.fill")
                        }
                        .buttonStyle(PKPillButtonStyle(variant: .secondary))
                        .accessibilityIdentifier("exportPreviewButton")
                    }
                } else {
                    Button {} label: {
                        Label(label, systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PKPillButtonStyle(variant: .secondary))
                    .disabled(true)
                }
            }

            if let imageToSave {
                Button {
                    saveImageToPhotos(imageToSave)
                } label: {
                    Label(
                        savedToPhotos ? "Saved to Photos" : "Save to Photos",
                        systemImage: savedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PKPillButtonStyle(variant: .ink, compact: true))
                .disabled(savedToPhotos)
            }

            if let photoSaveError {
                Text(photoSaveError)
                    .font(PKFont.body(.caption))
                    .foregroundStyle(PKColors.error)
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let fileURL {
                QuickLookPreviewSheet(url: fileURL)
            }
        }
    }

    private func saveImageToPhotos(_ image: UIImage) {
        let saver = PhotoLibrarySaver { error in
            if let error {
                photoSaveError = error.localizedDescription
                PKHaptics.error()
            } else {
                savedToPhotos = true
                photoSaveError = nil
                PKHaptics.success()
            }
        }
        saver.save(image)
    }
}

private final class PhotoLibrarySaver: NSObject, @unchecked Sendable {
    private let completion: @MainActor (Error?) -> Void
    @MainActor private static var activeSavers: [PhotoLibrarySaver] = []

    init(completion: @escaping @MainActor (Error?) -> Void) {
        self.completion = completion
    }

    @MainActor
    func save(_ image: UIImage) {
        Self.activeSavers.append(self)
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(handleSave(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc private func handleSave(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer?) {
        Task { @MainActor in
            self.completion(error)
            Self.activeSavers.removeAll { $0 === self }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// Complete DownloadResult card matching website's DownloadResult.jsx.
struct ToolResultCard: View {
    let title: String
    var subtitle: String = ""
    let fileURL: URL?
    var originalBytes: Int64? = nil
    var outputBytes: Int64? = nil
    var metrics: [(label: String, value: String)] = []
    var exportLabel: String = "Export File"
    var imageToSave: UIImage? = nil
    var onReset: (() -> Void)? = nil

    @State private var appeared = false

    private var savedPercent: Double? {
        guard let orig = originalBytes, let out = outputBytes, orig > 0, out > 0 else { return nil }
        return (Double(orig - out) / Double(orig)) * 100.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(PKColors.successSoft)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(PKColors.success)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(PKFont.display(.headline, weight: .bold))
                        .foregroundStyle(PKColors.textPrimary)
                        .lineLimit(2)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(PKFont.body(.caption))
                            .foregroundStyle(PKColors.textSecondary)
                    }
                }

                Spacer(minLength: 8)

                if let savedPercent {
                    let text = savedPercent >= 0
                        ? String(format: "-%.1f%%", savedPercent)
                        : String(format: "+%.1f%%", abs(savedPercent))
                    PKTagBadge(
                        text: text,
                        tone: savedPercent >= 0 ? .success : .neutral
                    )
                }
            }

            if originalBytes != nil || outputBytes != nil || !metrics.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                    if let originalBytes, originalBytes > 0 {
                        ToolMetricTile(label: "Original", value: ByteCountFormatter.string(fromByteCount: originalBytes, countStyle: .file))
                    }
                    if let outputBytes, outputBytes > 0 {
                        ToolMetricTile(
                            label: "Output",
                            value: ByteCountFormatter.string(fromByteCount: outputBytes, countStyle: .file),
                            accent: true
                        )
                    }
                    ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                        ToolMetricTile(label: metric.label, value: metric.value)
                    }
                }
            }

            ExportButton(fileURL: fileURL, label: exportLabel, imageToSave: imageToSave)

            if let onReset {
                Button(action: onReset) {
                    Label("Start Another File", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PKPillButtonStyle(variant: .ghost, compact: true))
            }
        }
        .pkCard(background: PKColors.surface, border: PKColors.success.opacity(0.32), padding: 16)
        .scaleEffect(appeared ? 1 : 0.97)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }
}
