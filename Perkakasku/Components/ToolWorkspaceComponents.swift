import SwiftUI

/// Tool workbench privacy notice banner mirroring website's `.pk-privacy-notice`.
struct ToolPrivacyBanner: View {
    let mode: ProcessingMode
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: mode == .local ? "lock.shield.fill" : "checkmark.shield.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(mode == .local ? PKColors.success : PKColors.brand)
                .padding(.top, 1)

            Text(text)
                .font(PKFont.body(.caption))
                .foregroundStyle(PKColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            mode == .local ? PKColors.successSoft.opacity(0.65) : PKColors.brandSoft.opacity(0.65),
            in: RoundedRectangle(cornerRadius: PKRadius.sm, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PKRadius.sm, style: .continuous)
                .strokeBorder(mode == .local ? PKColors.success.opacity(0.28) : PKColors.brandBorder, lineWidth: 1)
        )
    }
}

/// Container panel for tool settings mirroring `.pk-settings-panel`.
struct ToolSettingsCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var badge: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PKFont.display(.headline, weight: .bold))
                        .foregroundStyle(PKColors.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(PKFont.body(.caption))
                            .foregroundStyle(PKColors.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                if let badge {
                    PKTagBadge(text: badge, tone: .neutral)
                }
            }

            content
        }
        .pkCard(background: PKColors.surface, border: PKColors.border, padding: 16)
    }
}

/// Selectable radio option card matching `.pk-radio-card`.
struct ToolOptionCard: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            PKHaptics.selection()
            action()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? PKColors.brand : PKColors.textMuted)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PKFont.body(.subheadline, weight: .semibold))
                        .foregroundStyle(PKColors.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(PKFont.body(.caption))
                            .foregroundStyle(PKColors.textMuted)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? PKColors.brandSoft : PKColors.backgroundInset,
                in: RoundedRectangle(cornerRadius: PKRadius.sm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PKRadius.sm, style: .continuous)
                    .strokeBorder(isSelected ? PKColors.brand : PKColors.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PKPressButtonStyle())
    }
}

/// Metric summary tile used in result cards and analytics grids.
struct ToolMetricTile: View {
    let label: String
    let value: String
    var accent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(PKFont.body(.caption2))
                .foregroundStyle(PKColors.textMuted)
            Text(value)
                .font(PKFont.mono(.subheadline, weight: .bold))
                .foregroundStyle(accent ? PKColors.brand : PKColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pkInsetCard(radius: PKRadius.sm, padding: 10)
    }
}

/// Selected file item row matching `.pk-file-item`.
struct ToolFileItemRow: View {
    let fileName: String
    let meta: String
    var icon: String = "doc.fill"
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PKColors.brandSoft)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PKColors.brand)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(PKFont.body(.subheadline, weight: .semibold))
                    .foregroundStyle(PKColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(meta)
                    .font(PKFont.mono(.caption2, weight: .medium))
                    .foregroundStyle(PKColors.textMuted)
            }

            Spacer(minLength: 8)

            if let onRemove {
                Button {
                    PKHaptics.impact(.light)
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(PKColors.textMuted)
                }
                .accessibilityLabel("Remove \(fileName)")
            }
        }
        .pkInsetCard(radius: PKRadius.sm, padding: 10)
    }
}

/// Checkerboard pattern for transparent PNG previews matching `.pk-checkerboard`.
struct CheckerboardBackground: View {
    var squareSize: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))
            for r in 0..<rows {
                for c in 0..<cols where (r + c).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(c) * squareSize,
                        y: CGFloat(r) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(PKColors.backgroundSecondary))
                }
            }
        }
        .background(PKColors.surface)
    }
}
