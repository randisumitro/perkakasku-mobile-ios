import SwiftUI

struct SuccessView: View {
    let message: String
    var title: String = "Ready to Export"
    var onDone: (() -> Void)? = nil

    @State private var scale: CGFloat = 0.7
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PKColors.successSoft)
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(PKColors.success)
                    .scaleEffect(reduceMotion ? 1.0 : scale)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(PKFont.display(.title3, weight: .bold))
                    .foregroundStyle(PKColors.textPrimary)
                Text(message)
                    .font(PKFont.body(.subheadline))
                    .foregroundStyle(PKColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let onDone {
                Button("Done", action: onDone)
                    .buttonStyle(PKPillButtonStyle(variant: .ink, compact: true))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .pkCard(background: PKColors.surface, border: PKColors.success.opacity(0.3), padding: 20)
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.65)) {
                    scale = 1.0
                }
            }
            PKHaptics.success()
        }
    }
}
