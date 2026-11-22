import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var actionIcon: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous)
                    .fill(PKColors.surface)
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous)
                            .strokeBorder(PKColors.border, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PKColors.brand)
            }

            VStack(spacing: 5) {
                Text(title)
                    .font(PKFont.display(.headline, weight: .bold))
                    .foregroundStyle(PKColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(PKFont.body(.subheadline))
                    .foregroundStyle(PKColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 6) {
                        if let actionIcon {
                            Image(systemName: actionIcon)
                        }
                        Text(actionTitle)
                    }
                }
                .buttonStyle(PKPillButtonStyle(variant: .ink, compact: true))
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(
            PKColors.backgroundInset,
            in: RoundedRectangle(cornerRadius: PKRadius.lg, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PKRadius.lg, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.25, dash: [6, 5]))
                .foregroundStyle(PKColors.borderStrong)
        )
    }
}
