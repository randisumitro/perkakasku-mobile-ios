// xcode: set sdk=iOS

import SwiftUI

/// Redesigned editorial Perkakasku Home screen inspired directly by the Perkakasku website.
/// Open immediately in Guest Mode — zero login wall, zero fabricated telemetry.
struct HomeView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var registry: ToolRegistryService
    @EnvironmentObject private var history: HistoryService
    @EnvironmentObject private var favorites: FavoritesService
    @EnvironmentObject private var settings: AppSettingsService

    @State private var searchText = ""
    @State private var featuredIndex = 0
    @State private var showingPremiumSheet = false

    private var featuredTools: [Tool] {
        registry.tools.filter { $0.isFeatured }
    }

    private var popularTools: [Tool] {
        ToolRegistry.popularSlugs.compactMap { slug in
            registry.tool(slug: slug)
        }
    }

    private var searchResults: [Tool] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return registry.tools.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.toolDescription.localizedCaseInsensitiveContains(q)
                || $0.category.displayName.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PKStudioBackdrop(showGrid: true)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        brandedHeader
                            .pkStaggered(index: 0)

                        welcomeHero
                            .pkStaggered(index: 1)

                        interactiveSearchSection
                            .pkStaggered(index: 2)

                        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            searchResultsSection
                        } else {
                            featuredEspressoStage
                                .pkStaggered(index: 3)

                            categoriesSection
                                .pkStaggered(index: 4)

                            popularToolsSection
                                .pkStaggered(index: 5)

                            recentToolsSection
                                .pkStaggered(index: 6)

                            quickActionsSection
                                .pkStaggered(index: 7)

                            premiumBannerSection
                                .pkStaggered(index: 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Tool.self) { tool in
                ToolDetailView(tool: tool)
            }
            .sheet(isPresented: $showingPremiumSheet) {
                PremiumView()
            }
        }
    }

    // MARK: - 1. Branded Header

    private var brandedHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                PKLogoMark(size: 34)
                PKBrandWordmark(fontSize: 22)
                    .accessibilityIdentifier("home_wordmark")
            }

            Spacer(minLength: 8)

            // Live backend & guest status badge
            Button {
                settings.selectedTab = .settings
                PKHaptics.selection()
            } label: {
                HStack(spacing: 6) {
                    PKLiveDot(color: statusDotColor)
                    Text(statusShortLabel)
                        .font(PKFont.mono(.caption2, weight: .semibold))
                        .foregroundStyle(PKColors.textSecondary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(PKColors.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(PKColors.borderStrong, lineWidth: 1))
            }
            .buttonStyle(PKPressButtonStyle())
            .accessibilityLabel("Workspace backend status: \(settings.backendStatus.label)")
            .accessibilityIdentifier("home_status_pill")
        }
    }

    private var statusDotColor: Color {
        switch settings.backendStatus {
        case .online: return PKColors.success
        case .checking, .unknown: return PKColors.brandVivid
        case .unreachable: return PKColors.warning
        }
    }

    private var statusShortLabel: String {
        switch settings.backendStatus {
        case .online(let ms, _): return "Studio · \(ms)ms"
        case .checking: return "Checking…"
        case .unknown: return auth.effectiveDisplayName
        case .unreachable: return "Local Ready"
        }
    }

    // MARK: - 2. Welcome Section (No Auth Required)

    private var welcomeHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PKColors.brand)
                Text("GUEST WORKSPACE · ZERO SIGN-IN")
                    .font(PKFont.mono(.caption2, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(PKColors.brand)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(PKColors.brandSoft, in: Capsule())
            .overlay(Capsule().strokeBorder(PKColors.brandBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: 8) {
                Text("Process documents, photos & utilities cleanly.")
                    .font(PKFont.display(.title2, weight: .bold))
                    .foregroundStyle(PKColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(registry.allLocalTools.count) tools run 100% on your iPhone. \(registry.allServerTools.count) format converters use your Perkakasku sandbox with immediate memory cleanup.")
                    .font(PKFont.body(.subheadline))
                    .foregroundStyle(PKColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    settings.openTools(category: nil)
                } label: {
                    HStack(spacing: 6) {
                        Text("Explore \(registry.tools.count) Tools")
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PKPillButtonStyle(variant: .ink))
                .accessibilityIdentifier("home_explore_tools_button")

                if history.totalProcessedCount > 0 {
                    Button {
                        settings.selectedTab = .history
                        PKHaptics.selection()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("\(history.totalProcessedCount) Runs")
                                .font(PKFont.mono(.footnote, weight: .bold))
                        }
                    }
                    .buttonStyle(PKPillButtonStyle(variant: .secondary))
                } else {
                    Button {
                        settings.openTools(category: .pdf)
                    } label: {
                        Label("PDF Suite", systemImage: "doc.richtext")
                    }
                    .buttonStyle(PKPillButtonStyle(variant: .secondary))
                }
            }
        }
        .pkCard(radius: PKRadius.lg, background: PKColors.surface, border: PKColors.borderStrong, padding: 18)
    }

    // MARK: - 3. Interactive Search Bar

    private var interactiveSearchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PKColors.brand)

                TextField("Find a tool (Compress PDF, Crop, OCR, QR…)", text: $searchText)
                    .font(PKFont.body(.subheadline))
                    .foregroundStyle(PKColors.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .accessibilityIdentifier("home_search_field")

                if !searchText.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(PKColors.textMuted)
                    }
                    .accessibilityLabel("Clear home search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PKColors.surface, in: RoundedRectangle(cornerRadius: PKRadius.pill, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PKRadius.pill, style: .continuous)
                    .strokeBorder(
                        searchText.isEmpty ? PKColors.borderStrong : PKColors.brand,
                        lineWidth: searchText.isEmpty ? 1 : 1.5
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Search Results",
                subtitle: "\(searchResults.count) matching tool(s)",
                actionTitle: "Clear",
                action: { searchText = "" }
            )

            if searchResults.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No tools found",
                    subtitle: "No tools match \"\(searchText)\". Browse the full catalog to see all 21 utilities.",
                    actionTitle: "Open Catalog",
                    actionIcon: "square.grid.2x2.fill"
                ) {
                    settings.openTools(category: nil)
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(searchResults) { tool in
                        NavigationLink(value: tool) {
                            ToolRowView(tool: tool)
                        }
                        .buttonStyle(PKPressButtonStyle())
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - 4. Featured Tools (Espresso Architectural Stage)

    private var featuredEspressoStage: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Featured Studio Tools",
                eyebrow: "Spotlight Workbench",
                actionTitle: "All \(registry.tools.count)",
                action: { settings.openTools(category: nil) }
            )

            if !featuredTools.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    TabView(selection: $featuredIndex) {
                        ForEach(Array(featuredTools.enumerated()), id: \.element.id) { index, tool in
                            NavigationLink(value: tool) {
                                featuredStageSlide(tool: tool, step: index + 1, total: featuredTools.count)
                            }
                            .buttonStyle(PKPressButtonStyle())
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 190)

                    // Interactive pipeline step selector pills matching StudioArchitectureHero
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(featuredTools.enumerated()), id: \.element.id) { index, tool in
                                let active = featuredIndex == index
                                Button {
                                    PKHaptics.selection()
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                        featuredIndex = index
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(String(format: "0%d", index + 1))
                                            .font(PKFont.mono(.caption2, weight: .bold))
                                        Text(tool.name)
                                            .font(PKFont.body(.caption, weight: .semibold))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .foregroundStyle(active ? .white : PKColors.espressoMuted)
                                    .background(
                                        active ? PKColors.brandVivid : PKColors.espressoElevated,
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(active ? Color.clear : PKColors.espressoBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .background(PKColors.espressoSurface, in: RoundedRectangle(cornerRadius: PKRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PKRadius.lg, style: .continuous)
                        .strokeBorder(PKColors.espressoBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
            }
        }
    }

    private func featuredStageSlide(tool: Tool, step: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text(String(format: "%02d / %02d", step, total))
                        .font(PKFont.mono(.caption2, weight: .bold))
                        .foregroundStyle(PKColors.brandVivid)
                    Text("·")
                        .foregroundStyle(PKColors.espressoMuted)
                    Text(tool.category.shortName.uppercased())
                        .font(PKFont.mono(.caption2, weight: .semibold))
                        .foregroundStyle(PKColors.espressoMuted)
                }

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: tool.isLocalOnly ? "lock.fill" : "shield.checkered")
                        .font(.caption2)
                    Text(tool.mode.displayLabel)
                        .font(PKFont.mono(.caption2, weight: .semibold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .foregroundStyle(PKColors.espressoText)
                .background(PKColors.espressoElevated, in: Capsule())
                .overlay(Capsule().strokeBorder(PKColors.espressoBorder, lineWidth: 1))
            }

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PKColors.brandVivid.opacity(0.18))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(PKColors.brandVivid.opacity(0.45), lineWidth: 1)
                        )
                    Image(systemName: tool.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(PKColors.brandVivid)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.name)
                        .font(PKFont.display(.title3, weight: .bold))
                        .foregroundStyle(PKColors.espressoText)
                    Text(tool.toolDescription)
                        .font(PKFont.body(.caption))
                        .foregroundStyle(PKColors.espressoMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Text(tool.inputHint)
                    .font(PKFont.mono(.caption2, weight: .medium))
                    .foregroundStyle(PKColors.espressoMuted)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 5) {
                    Text("Launch")
                    Image(systemName: "arrow.right")
                }
                .font(PKFont.body(.caption, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(PKColors.brandVivid, in: Capsule())
            }
        }
        .padding(14)
        .background(PKColors.espressoElevated.opacity(0.85), in: RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PKRadius.md, style: .continuous)
                .strokeBorder(PKColors.espressoBorder, lineWidth: 1)
        )
    }

    // MARK: - 5. Tool Categories

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Tool Categories",
                subtitle: "Organized by document workflow"
            )

            VStack(spacing: 10) {
                ForEach(ToolCategory.allCases) { category in
                    let count = registry.tools(in: category).count
                    Button {
                        settings.openTools(category: category)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(categoryAccentSoft(category))
                                    .frame(width: 44, height: 44)
                                Image(systemName: category.systemIcon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(categoryAccent(category))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(category.displayName)
                                        .font(PKFont.display(.subheadline, weight: .bold))
                                        .foregroundStyle(PKColors.textPrimary)
                                    Text("\(count) tools")
                                        .font(PKFont.mono(.caption2, weight: .semibold))
                                        .foregroundStyle(categoryAccent(category))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(categoryAccentSoft(category), in: Capsule())
                                }
                                Text(category.tagline)
                                    .font(PKFont.body(.caption))
                                    .foregroundStyle(PKColors.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 4)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PKColors.textMuted)
                        }
                        .pkCard(radius: PKRadius.md, background: PKColors.surface, border: PKColors.border, padding: 13)
                    }
                    .buttonStyle(PKPressButtonStyle())
                    .accessibilityIdentifier("home_category_\(category.rawValue)")
                }
            }
        }
    }

    private func categoryAccent(_ category: ToolCategory) -> Color {
        switch category {
        case .pdf: return PKColors.brand
        case .image: return PKColors.textPrimary
        case .document: return PKColors.success
        }
    }

    private func categoryAccentSoft(_ category: ToolCategory) -> Color {
        switch category {
        case .pdf: return PKColors.brandSoft
        case .image: return PKColors.backgroundTertiary
        case .document: return PKColors.successSoft
        }
    }

    // MARK: - 6. Popular Tools

    private var popularToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Most Used Workbenches",
                eyebrow: "Popular",
                actionTitle: "See All",
                action: { settings.openTools(category: nil) }
            )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 158), spacing: 12)],
                spacing: 12
            ) {
                ForEach(popularTools) { tool in
                    NavigationLink(value: tool) {
                        ToolCard(tool: tool)
                    }
                    .buttonStyle(PKPressButtonStyle())
                }
            }
        }
    }

    // MARK: - 7. Recently Used Tools (Real Local History)

    private var recentToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Recently Used",
                eyebrow: "Continue",
                actionTitle: history.items.isEmpty ? nil : "Full Log",
                action: {
                    settings.selectedTab = .history
                    PKHaptics.selection()
                }
            )

            RecentView()
        }
    }

    // MARK: - 8. Quick-Access Actions

    private var quickActionsSection: some View {
        let quickSlugs: [(slug: String, label: String, subtitle: String)] = [
            ("qr-code", "Instant QR", "PNG & Vector SVG"),
            ("ocr", "Scan & OCR", "Extract text offline"),
            ("pdf-merge", "Merge PDFs", "Combine pages"),
            ("passport-photo", "ID Photo 300 DPI", "Cutout & background"),
        ]

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Quick-Access Actions",
                subtitle: "Jump straight into one-tap workflows"
            )

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(quickSlugs, id: \.slug) { item in
                    if let tool = registry.tool(slug: item.slug) {
                        NavigationLink(value: tool) {
                            HStack(spacing: 10) {
                                Image(systemName: tool.iconName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PKColors.brand)
                                    .frame(width: 34, height: 34)
                                    .background(PKColors.brandSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.label)
                                        .font(PKFont.body(.subheadline, weight: .bold))
                                        .foregroundStyle(PKColors.textPrimary)
                                        .lineLimit(1)
                                    Text(item.subtitle)
                                        .font(PKFont.body(.caption2))
                                        .foregroundStyle(PKColors.textMuted)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .pkCard(radius: PKRadius.md, background: PKColors.surface, border: PKColors.border, padding: 12)
                        }
                        .buttonStyle(PKPressButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - 9. Plans & Sandbox Quotas Banner

    private var premiumBannerSection: some View {
        Button {
            PKHaptics.impact(.light)
            showingPremiumSheet = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PKColors.brandVivid.opacity(0.2))
                        .frame(width: 46, height: 46)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(PKColors.brandVivid)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Perkakasku Pro Studio")
                        .font(PKFont.display(.headline, weight: .bold))
                        .foregroundStyle(PKColors.espressoText)
                    Text("All 21 tools run free in Guest Mode. Compare higher sandbox upload quotas & plans.")
                        .font(PKFont.body(.caption))
                        .foregroundStyle(PKColors.espressoMuted)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PKColors.brandVivid)
            }
            .padding(16)
            .background(PKColors.espressoSurface, in: RoundedRectangle(cornerRadius: PKRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PKRadius.lg, style: .continuous)
                    .strokeBorder(PKColors.espressoBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PKPressButtonStyle())
        .accessibilityIdentifier("home_premium_button")
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthService.shared)
        .environmentObject(ToolRegistryService.shared)
        .environmentObject(HistoryService.shared)
        .environmentObject(FavoritesService.shared)
        .environmentObject(AppSettingsService.shared)
}
