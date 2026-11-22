import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var eyebrow: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(PKFont.mono(.caption2, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(PKColors.brand)
                }
                Text(title)
                    .font(PKFont.display(.title3, weight: .bold))
                    .foregroundStyle(PKColors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(PKFont.body(.caption))
                        .foregroundStyle(PKColors.textSecondary)
                }
            }

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                    }
                    .font(PKFont.body(.subheadline, weight: .semibold))
                    .foregroundStyle(PKColors.brand)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading = false
    var variant: PKPillButtonStyle.Variant = .primary
    var action: () -> Void

    var body: some View {
        Button {
            PKHaptics.impact(.light)
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(variant == .ink ? PKColors.inkCTAText : .white)
                        .controlSize(.small)
                } else if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PKPillButtonStyle(variant: variant))
        .disabled(isLoading)
    }
}
