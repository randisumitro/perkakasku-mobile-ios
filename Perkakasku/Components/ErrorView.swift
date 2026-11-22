import SwiftUI

struct ErrorView: View {
    let message: String
    var title: String = "Something went wrong"
    var onRetry: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PKColors.error)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(PKFont.body(.subheadline, weight: .bold))
                        .foregroundStyle(PKColors.error)
                    Text(message)
                        .font(PKFont.body(.footnote))
                        .foregroundStyle(PKColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PKColors.textMuted)
                            .padding(6)
                    }
                    .accessibilityLabel("Dismiss error")
                }
            }

            if let onRetry {
                Button {
                    PKHaptics.impact(.light)
                    onRetry()
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(PKPillButtonStyle(variant: .secondary, compact: true))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PKColors.errorSoft, in: RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous)
                .strokeBorder(PKColors.error.opacity(0.32), lineWidth: 1)
        )
    }
}
