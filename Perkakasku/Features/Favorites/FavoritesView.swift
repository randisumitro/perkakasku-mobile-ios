// xcode: set sdk=iOS

import SwiftUI

/// Starred tools persisted locally via `FavoritesService`.
struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoritesService
    @EnvironmentObject private var registry: ToolRegistryService
    @EnvironmentObject private var settings: AppSettingsService

    @State private var searchText = ""

    private var favoriteTools: [Tool] {
        let starred = favorites.favoriteTools(from: registry.tools)
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return starred }
        return starred.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.toolDescription.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PKStudioBackdrop(showGrid: false)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if favorites.favoriteSlugs.isEmpty {
                            EmptyStateView(
                                icon: "heart",
                                title: "No favorite tools yet",
                                subtitle: "Tap the heart button on any tool card or detail screen to pin your daily workbenches here.",
                                actionTitle: "Browse All 21 Tools",
                                actionIcon: "square.grid.2x2.fill"
                            ) {
                                settings.openTools(category: nil)
                            }
                            .padding(.top, 40)
                        } else if favoriteTools.isEmpty {
                            EmptyStateView(
                                icon: "magnifyingglass",
                                title: "No matching favorites",
                                subtitle: "Try another keyword or browse all tools."
                            )
                            .padding(.top, 40)
                        } else {
                            HStack {
                                Text("\(favoriteTools.count) PINNED TOOLS")
                                    .font(PKFont.mono(.caption2, weight: .bold))
                                    .foregroundStyle(PKColors.brand)
                                Spacer()
                            }

                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 158), spacing: 12)],
                                spacing: 12
                            ) {
                                ForEach(Array(favoriteTools.enumerated()), id: \.element.id) { idx, tool in
                                    NavigationLink(value: tool) {
                                        ToolCard(tool: tool)
                                    }
                                    .buttonStyle(PKPressButtonStyle())
                                    .pkStaggered(index: idx)
                                    .accessibilityIdentifier("tool_card_\(tool.slug)")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Favorites")
            .searchable(text: $searchText, prompt: "Search starred tools")
            .navigationDestination(for: Tool.self) { tool in
                ToolDetailView(tool: tool)
            }
        }
    }
}

#Preview {
    FavoritesView()
        .environmentObject(FavoritesService.shared)
        .environmentObject(ToolRegistryService.shared)
        .environmentObject(AppSettingsService.shared)
}
