// xcode: set sdk=iOS

import SwiftUI

/// Row displaying one persisted `ProcessedItemModel` entry with preview/share affordances.
struct HistoryRowView: View {
    let item: ProcessedItemModel
    var onPreview: ((URL, String) -> Void)? = nil

    private var outputURL: URL? {
        guard let str = item.outputURLString,
              let url = URL(string: str),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    private var isCompleted: Bool {
        item.statusRaw == ProcessingStatus.completed.rawValue
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isCompleted ? PKColors.successSoft : PKColors.errorSoft)
                    .frame(width: 40, height: 40)
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isCompleted ? PKColors.success : PKColors.error)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.toolName)
                        .font(PKFont.display(.subheadline, weight: .bold))
                        .foregroundStyle(PKColors.textPrimary)
                        .lineLimit(1)

                    PKTagBadge(
                        text: isCompleted ? "Saved" : "Failed",
                        tone: isCompleted ? .success : .error
                    )
                }

                Text(item.outputFileName ?? item.inputFileName)
                    .font(PKFont.body(.caption))
                    .foregroundStyle(PKColors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if item.fileSize > 0 {
                        Text("·")
                        Text(ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file))
                    }
                }
                .font(PKFont.mono(.caption2, weight: .regular))
                .foregroundStyle(PKColors.textMuted)
            }

            Spacer(minLength: 6)

            if let outputURL {
                HStack(spacing: 6) {
                    Button {
                        PKHaptics.impact(.light)
                        onPreview?(outputURL, item.outputFileName ?? item.toolName)
                    } label: {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PKColors.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(PKColors.backgroundInset, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Preview \(item.outputFileName ?? item.toolName)")

                    ShareLink(item: outputURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PKColors.brand)
                            .frame(width: 32, height: 32)
                            .background(PKColors.brandSoft, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .pkCard(radius: PKRadius.md, background: PKColors.surface, border: PKColors.border, padding: 12)
        .contentShape(Rectangle())
    }
}
