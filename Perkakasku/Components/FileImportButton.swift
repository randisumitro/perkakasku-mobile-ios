import SwiftUI
import UniformTypeIdentifiers

/// Architectural file import dropzone matching the Perkakasku website `.pk-dropzone`.
/// Automatically copies security-scoped imported URLs into app cache so downstream tools can read reliably.
struct FileImportButton: View {
    var title: String = "Select File from Device"
    var hint: String = "Tap to browse Files, iCloud Drive, or Downloads"
    var icon: String = "doc.badge.plus"
    var allowedUTIs: [String] = []
    var allowsMultiple: Bool = false
    var compact: Bool = false
    var onError: ((String) -> Void)? = nil
    var onImport: ([URL]) -> Void

    @State private var showingPicker = false
    @State private var isPressed = false

    var body: some View {
        Button {
            PKHaptics.impact(.light)
            showingPicker = true
        } label: {
            if compact {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                    Text(title)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous)
                            .fill(PKColors.surface)
                            .frame(width: 52, height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous)
                                    .strokeBorder(PKColors.border, lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(PKColors.brand)
                    }

                    VStack(spacing: 4) {
                        Text(title)
                            .font(PKFont.display(.headline, weight: .bold))
                            .foregroundStyle(PKColors.textPrimary)
                        Text(hint)
                            .font(PKFont.body(.caption))
                            .foregroundStyle(PKColors.textMuted)
                            .multilineTextAlignment(.center)
                    }

                    Text(allowsMultiple ? "Choose Files" : "Choose File")
                        .font(PKFont.body(.footnote, weight: .semibold))
                        .foregroundStyle(PKColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(PKColors.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(PKColors.borderStrong, lineWidth: 1))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: PKRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PKRadius.lg, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                        .foregroundStyle(PKColors.borderStrong)
                )
            }
        }
        .buttonStyle(PKPressButtonStyle())
        .accessibilityIdentifier("fileImportButton")
        .fileImporter(
            isPresented: $showingPicker,
            allowedContentTypes: contentTypes,
            allowsMultipleSelection: allowsMultiple
        ) { result in
            switch result {
            case .success(let urls):
                var imported: [URL] = []
                for url in urls {
                    do {
                        let copied = try FileService.shared.importFile(at: url)
                        imported.append(copied)
                    } catch {
                        onError?("Could not import \(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
                if !imported.isEmpty {
                    PKHaptics.impact(.light)
                    onImport(imported)
                }
            case .failure(let error):
                onError?("File selection failed: \(error.localizedDescription)")
            }
        }
    }

    private var contentTypes: [UTType] {
        if allowedUTIs.isEmpty { return [.item] }
        let resolved = allowedUTIs.compactMap { UTType($0) }
        return resolved.isEmpty ? [.item] : resolved
    }
}
