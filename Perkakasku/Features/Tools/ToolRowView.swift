// xcode: set sdk=iOS

import SwiftUI

/// Horizontal full-width tool row used in Catalog list mode and search results.
struct ToolRowView: View {
    let tool: Tool

    @EnvironmentObject private var favorites: FavoritesService

    private var isFav: Bool { favorites.isFavorite(tool.slug) }

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)
                Image(systemName: tool.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconForeground)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(tool.name)
                        .font(PKFont.display(.subheadline, weight: .bold))
                        .foregroundStyle(PKColors.textPrimary)
                        .lineLimit(1)

                    PKModeBadge(mode: tool.mode)
                }

                Text(tool.toolDescription)
                    .font(PKFont.body(.caption))
                    .foregroundStyle(PKColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 6)

            Button {
                favorites.toggle(tool.slug)
            } label: {
                Image(systemName: isFav ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isFav ? PKColors.brandVivid : PKColors.textMuted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFav ? "Unfavorite \(tool.name)" : "Favorite \(tool.name)")

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(PKColors.textMuted)
        }
        .pkCard(radius: PKRadius.md, background: PKColors.surface, border: PKColors.border, padding: 13)
        .contentShape(Rectangle())
    }

    private var iconBackground: Color {
        switch tool.category {
        case .pdf: return PKColors.brandSoft
        case .image: return PKColors.backgroundTertiary
        case .document: return PKColors.successSoft
        }
    }

    private var iconForeground: Color {
        switch tool.category {
        case .pdf: return PKColors.brand
        case .image: return PKColors.textPrimary
        case .document: return PKColors.success
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        ToolRowView(tool: ToolRegistry.all[0])
        ToolRowView(tool: ToolRegistry.all[16])
    }
    .padding()
    .background(PKColors.background)
    .environmentObject(FavoritesService.shared)
}
