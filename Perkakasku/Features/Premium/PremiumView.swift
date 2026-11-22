// xcode: set sdk=iOS

import SwiftUI

/// Plans & Sandbox Limits view synced live with `GET /api/v1/public/plans` when backend is reachable.
struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsService

    @State private var isLoading = false
    @State private var loadError: String?
    @State private var selectedPlan: PublicPlan?

    var body: some View {
        NavigationStack {
            ZStack {
                PKStudioBackdrop(showGrid: true)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        heroBanner

                        if isLoading && settings.availablePlans.isEmpty {
                            LoadingView(message: "Loading live studio plans…")
                        } else if let loadError, settings.availablePlans.isEmpty {
                            ErrorView(
                                message: loadError,
                                title: "Could not load server plans",
                                onRetry: {
                                    Task { await fetchPlans() }
                                }
                            )
                        } else {
                            ForEach(settings.availablePlans) { plan in
                                planCard(plan)
                            }
                        }

                        localIncludedCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Plans & Quotas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if settings.availablePlans.isEmpty {
                    await fetchPlans()
                }
            }
            .alert(item: $selectedPlan) { plan in
                Alert(
                    title: Text(plan.name),
                    message: Text("Guest Studio already unlocks all 21 tools in this build. Billing & team account upgrades are managed via perkakasku.cloud when authentication is enabled."),
                    dismissButton: .default(Text("Got it"))
                )
            }
        }
    }

    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                PKLiveDot(color: PKColors.brandVivid)
                Text("GUEST WORKSPACE ACTIVE")
                    .font(PKFont.mono(.caption2, weight: .bold))
                    .foregroundStyle(PKColors.brandVivid)
            }

            Text("Every on-device tool works unlimited, ad-free, and offline.")
                .font(PKFont.display(.title3, weight: .bold))
                .foregroundStyle(PKColors.espressoText)

            Text("Server sandbox plans apply only to cloud conversion throughput and team accounts.")
                .font(PKFont.body(.caption))
                .foregroundStyle(PKColors.espressoMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(PKColors.espressoSurface, in: RoundedRectangle(cornerRadius: PKRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PKRadius.lg, style: .continuous)
                .strokeBorder(PKColors.espressoBorder, lineWidth: 1)
        )
    }

    private func planCard(_ plan: PublicPlan) -> some View {
        let isPaid = plan.price > 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                        .font(PKFont.display(.headline, weight: .bold))
                        .foregroundStyle(PKColors.textPrimary)
                    Text(plan.code.uppercased())
                        .font(PKFont.mono(.caption2, weight: .semibold))
                        .foregroundStyle(isPaid ? PKColors.brand : PKColors.textMuted)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(plan.formattedPrice)
                        .font(PKFont.mono(.title3, weight: .bold))
                        .foregroundStyle(PKColors.textPrimary)
                    Text(plan.intervalLabel)
                        .font(PKFont.body(.caption))
                        .foregroundStyle(PKColors.textMuted)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isPaid ? PKColors.brand : PKColors.success)
                            .padding(.top, 2)
                        Text(feature)
                            .font(PKFont.body(.subheadline))
                            .foregroundStyle(PKColors.textSecondary)
                    }
                }
            }

            Button {
                PKHaptics.selection()
                selectedPlan = plan
            } label: {
                Text(isPaid ? "View Plan Availability" : "Included in Guest Studio")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PKPillButtonStyle(variant: isPaid ? .primary : .secondary, compact: true))
        }
        .pkCard(
            radius: PKRadius.md,
            background: PKColors.surface,
            border: isPaid ? PKColors.brandBorder : PKColors.border,
            padding: 16
        )
    }

    private var localIncludedCard: some View {
        ToolSettingsCard(
            title: "Included Locally on iOS",
            subtitle: "Zero network needed, processed completely inside your device sandbox",
            badge: "21 TOOLS"
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Label("PDF Merge, Split, Protect, Watermark, Signature & Image Export", systemImage: "doc.richtext")
                Label("Apple Vision OCR (Indonesian & English) & Subject Cutout", systemImage: "sparkles")
                Label("300 DPI Passport Studio, HEIC -> JPG, Crop, Resize, QR & JSON", systemImage: "photo.stack")
            }
            .font(PKFont.body(.caption))
            .foregroundStyle(PKColors.textSecondary)
        }
    }

    private func fetchPlans() async {
        isLoading = true
        loadError = nil
        do {
            let plans = try await APIService.shared.fetchPublicPlans()
            settings.availablePlans = plans
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    PremiumView()
        .environmentObject(AppSettingsService.shared)
}
