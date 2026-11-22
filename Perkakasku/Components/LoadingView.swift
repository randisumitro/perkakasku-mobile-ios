import SwiftUI

struct LoadingView: View {
    let message: String
    var progress: Double? = nil

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(message: String = "Processing…", progress: Double? = nil) {
        self.message = message
        self.progress = progress
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PKColors.brandSoft)
                    .frame(width: 56, height: 56)
                    .scaleEffect(pulse && !reduceMotion ? 1.12 : 1.0)

                if let progress {
                    Circle()
                        .stroke(PKColors.borderStrong, lineWidth: 3.5)
                        .frame(width: 46, height: 46)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0.05, min(1.0, progress))))
                        .stroke(PKColors.brandVivid, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .frame(width: 46, height: 46)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.25), value: progress)
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(PKFont.mono(.caption2, weight: .bold))
                        .foregroundStyle(PKColors.textPrimary)
                } else {
                    ProgressView()
                        .tint(PKColors.brandVivid)
                        .scaleEffect(1.15)
                }
            }

            VStack(spacing: 4) {
                Text(message)
                    .font(PKFont.body(.subheadline, weight: .semibold))
                    .foregroundStyle(PKColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Please keep this screen open while processing finishes.")
                    .font(PKFont.body(.caption))
                    .foregroundStyle(PKColors.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .pkCard(background: PKColors.surfaceElevated, border: PKColors.brandBorder, padding: 20)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
