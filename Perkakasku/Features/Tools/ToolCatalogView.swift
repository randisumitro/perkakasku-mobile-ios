// xcode: set sdk=iOS

import SwiftUI

/// Filterable, searchable catalog of all 21 Perkakasku tools matching `.pk-directory` & ToolsPage.jsx.
struct ToolCatalogView: View {
    enum ModeFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case local = "On-Device"
        case server = "Sandbox"

        var id: String { rawValue }
    }

    enum LayoutMode {
        case grid, list
    }

    @EnvironmentObject private var registry: ToolRegistryService
    @EnvironmentObject private var settings: AppSettingsService
    @EnvironmentObject private var favorites: FavoritesService

    @State private var searchText = ""
    @State private var modeFilter: ModeFilter = .all
    @State private var layoutMode: LayoutMode = .grid
    @Namespace private var categoryNamespace

    private var filteredTools: [Tool] {
        registry.tools.filter { tool in
            let matchesCategory = settings.catalogCategoryFilter == nil || tool.category == settings.catalogCategoryFilter
            let matchesMode: Bool = switch modeFilter {
            case .all: true
            case .local: tool.isLocalOnly
            case .server: !tool.isLocalOnly
            }
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = q.isEmpty
                || tool.name.localizedCaseInsensitiveContains(q)
                || tool.toolDescription.localizedCaseInsensitiveContains(q)
                || tool.category.displayName.localizedCaseInsensitiveContains(q)
                || tool.slug.localizedCaseInsensitiveContains(q)
            return matchesCategory && matchesMode && matchesQuery
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PKStudioBackdrop(showGrid: true)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection
                        searchBar
                        categoryStrip
                        modeAndLayoutBar

                        if filteredTools.isEmpty {
                            EmptyStateView(
                                icon: "magnifyingglass",
                                title: "No tools match \"\(searchText)\"",
                                subtitle: "Try another keyword or clear your active category and mode filters.",
                                actionTitle: "Reset Filters",
                                actionIcon: "arrow.counterclockwise"
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    searchText = ""
                                    settings.catalogCategoryFilter = nil
                                    modeFilter = .all
                                }
                            }
                            .padding(.top, 16)
                        } else {
                            resultsSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Tool Directory")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Tool.self) { tool in
                ToolDetailView(tool: tool)
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(filteredTools.count) OF \(registry.tools.count) TOOLS READY")
                    .font(PKFont.mono(.caption2, weight: .bold))
                    .foregroundStyle(PKColors.brand)
                Text("Select a workbench to process documents, photos, and text natively or via encrypted sandbox.")
                    .font(PKFont.body(.caption))
                    .foregroundStyle(PKColors.textSecondary)
            }
            Spacer(minLength: 8)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PKColors.textMuted)

            TextField("Search PDF, compress, OCR, QR, background…", text: $searchText)
                .font(PKFont.body(.subheadline))
                .foregroundStyle(PKColors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .accessibilityIdentifier("catalog_search_field")

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(PKColors.textMuted)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(PKColors.surface, in: RoundedRectangle(cornerRadius: PKRadius.pill, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PKRadius.pill, style: .continuous)
                .strokeBorder(PKColors.borderStrong, lineWidth: 1)
        )
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "All", count: registry.tools.count, category: nil, id: "catalog_filter_all")
                ForEach(ToolCategory.allCases) { category in
                    let count = registry.tools(in: category).count
                    categoryChip(
                        title: category.shortName,
                        count: count,
                        category: category,
                        id: "catalog_filter_\(category.rawValue)"
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func categoryChip(title: String, count: Int, category: ToolCategory?, id: String) -> some View {
        let isSelected = settings.catalogCategoryFilter == category
        return Button {
            PKHaptics.selection()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                settings.catalogCategoryFilter = category
            }
        } label: {
            HStack(spacing: 6) {
                if let category {
                    Image(systemName: category.systemIcon)
                        .font(.caption.weight(.semibold))
                }
                Text(title)
                    .font(PKFont.body(.subheadline, weight: .semibold))
                Text("\(count)")
                    .font(PKFont.mono(.caption2, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (isSelected ? Color.white.opacity(0.22) : PKColors.backgroundSecondary),
                        in: Capsule()
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? .white : PKColors.textPrimary)
            .background {
                if isSelected {
                    Capsule()
                        .fill(PKColors.brandVivid)
                        .matchedGeometryEffect(id: "activeCategoryPill", in: categoryNamespace)
                } else {
                    Capsule()
                        .fill(PKColors.surface)
                }
            }
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : PKColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PKPressButtonStyle())
        .accessibilityIdentifier(id)
    }

    private var modeAndLayoutBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(ModeFilter.allCases) { item in
                    let selected = modeFilter == item
                    Button {
                        PKHaptics.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            modeFilter = item
                        }
                    } label: {
                        Text(item.rawValue)
                            .font(PKFont.mono(.caption, weight: .semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .foregroundStyle(selected ? PKColors.inkCTAText : PKColors.textSecondary)
                            .background(selected ? PKColors.inkCTA : PKColors.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(selected ? Color.clear : PKColors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 6)

            Button {
                PKHaptics.selection()
                withAnimation(.easeInOut(duration: 0.2)) {
                    layoutMode = (layoutMode == .grid) ? .list : .grid
                }
            } label: {
                Image(systemName: layoutMode == .grid ? "list.bullet" : "square.grid.2x2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PKColors.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(PKColors.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(PKColors.border, lineWidth: 1)
                    )
            }
            .accessibilityLabel(layoutMode == .grid ? "Switch to list layout" : "Switch to grid layout")
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        switch layoutMode {
        case .grid:
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 158), spacing: 12)],
                spacing: 12
            ) {
                ForEach(Array(filteredTools.enumerated()), id: \.element.id) { idx, tool in
                    NavigationLink(value: tool) {
                        ToolCard(tool: tool)
                    }
                    .buttonStyle(PKPressButtonStyle())
                    .pkStaggered(index: idx)
                    .accessibilityIdentifier("tool_card_\(tool.slug)")
                }
            }
        case .list:
            LazyVStack(spacing: 10) {
                ForEach(Array(filteredTools.enumerated()), id: \.element.id) { idx, tool in
                    NavigationLink(value: tool) {
                        ToolRowView(tool: tool)
                    }
                    .buttonStyle(PKPressButtonStyle())
                    .pkStaggered(index: idx)
                    .accessibilityIdentifier("tool_row_\(tool.slug)")
                }
            }
        }
    }
}

#Preview {
    ToolCatalogView()
        .environmentObject(ToolRegistryService.shared)
        .environmentObject(AppSettingsService.shared)
        .environmentObject(FavoritesService.shared)
}
