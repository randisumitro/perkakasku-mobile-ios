// xcode: set sdk=iOS

import SwiftUI

/// Branded architectural launch splash screen mirroring Perkakasku's website identity.
/// Flows automatically into `MainTabView` with a guest session (never blocks on login).
struct SplashView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var logoVisible = false
    @State private var ringExpanded = false
    @State private var wordmarkVisible = false
    @State private var badgeVisible = false
    @State private var didComplete = false

    var body: some View {
        ZStack {
            PKStudioBackdrop(showGrid: true)

            VStack(spacing: 20) {
                Spacer()

                ZStack {
                    // Subtle Signal Orange halo behind the architectural mark
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [PKColors.brandVivid.opacity(0.22), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 96
                            )
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(ringExpanded ? 1.05 : 0.72)
                        .opacity(ringExpanded ? 1 : 0)

                    // Expanding hairline orbit ring
                    Circle()
                        .strokeBorder(PKColors.brandBorder, lineWidth: 1.2)
                        .frame(width: 112, height: 112)
                        .scaleEffect(ringExpanded ? 1.0 : 0.65)
                        .opacity(ringExpanded ? 0.75 : 0)

                    PKLogoMark(size: 84)
                        .shadow(color: PKColors.brandVivid.opacity(0.24), radius: 22, y: 10)
                        .scaleEffect(logoVisible ? 1.0 : 0.7)
                        .opacity(logoVisible ? 1.0 : 0.0)
                }

                VStack(spacing: 10) {
                    PKBrandWordmark(fontSize: 34)
                        .offset(y: wordmarkVisible ? 0 : 12)
                        .opacity(wordmarkVisible ? 1 : 0)

                    Text("Document, Image & Utility Workbench")
                        .font(PKFont.body(.subheadline, weight: .medium))
                        .foregroundStyle(PKColors.textSecondary)
                        .opacity(badgeVisible ? 1 : 0)
                        .offset(y: badgeVisible ? 0 : 8)

                    HStack(spacing: 7) {
                        PKLiveDot(color: PKColors.brandVivid)
                        Text("21 Tools · On-Device & Isolated Sandbox")
                            .font(PKFont.mono(.caption2, weight: .semibold))
                            .foregroundStyle(PKColors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(PKColors.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(PKColors.border, lineWidth: 1))
                    .padding(.top, 4)
                    .opacity(badgeVisible ? 1 : 0)
                    .offset(y: badgeVisible ? 0 : 8)
                }

                Spacer()

                Text("GUEST WORKSPACE READY")
                    .font(PKFont.mono(.caption2, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(PKColors.textMuted)
                    .opacity(badgeVisible ? 0.85 : 0)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
        .accessibilityIdentifier("splashView")
        .contentShape(Rectangle())
        .onTapGesture {
            finishIfNeeded()
        }
        .task {
            await runSequence()
        }
    }

    private func runSequence() async {
        if reduceMotion {
            logoVisible = true
            ringExpanded = true
            wordmarkVisible = true
            badgeVisible = true
            try? await Task.sleep(for: .milliseconds(350))
            finishIfNeeded()
            return
        }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.72)) {
            logoVisible = true
        }
        withAnimation(.easeOut(duration: 0.65)) {
            ringExpanded = true
        }

        try? await Task.sleep(for: .milliseconds(160))
        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            wordmarkVisible = true
        }

        try? await Task.sleep(for: .milliseconds(140))
        withAnimation(.easeOut(duration: 0.36)) {
            badgeVisible = true
        }

        try? await Task.sleep(for: .milliseconds(620))
        finishIfNeeded()
    }

    private func finishIfNeeded() {
        guard !didComplete else { return }
        didComplete = true
        onFinished()
    }
}

#Preview {
    SplashView(onFinished: {})
}
