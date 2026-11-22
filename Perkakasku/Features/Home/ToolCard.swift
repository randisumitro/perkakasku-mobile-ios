// xcode: set sdk=iOS

import SwiftUI

/// Compact or standard studio card representing one Perkakasku tool.
struct ToolCard: View {
    let tool: Tool
    var compact: Bool = false

    @EnvironmentObject private var favorites: FavoritesService

    private var isFav: Bool { favorites.isFavorite(tool.slug) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconBackground)
                        .frame(width: compact ? 38 : 42, height: compact ? 38 : 42)
                    Image(systemName: tool.iconName)
                        .font(.system(size: compact ? 16 : 18, weight: .semibold))
                        .foregroundStyle(iconForeground)
                }

                Spacer(minLength: 6)

                Button {
                    favorites.toggle(tool.slug)
                } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isFav ? PKColors.brandVivid : PKColors.textMuted)
                        .frame(width: 28, height: 28)
                        .background(PKColors.backgroundInset, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFav ? "Remove \(tool.name) from favorites" : "Add \(tool.name) to favorites")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tool.name)
                    .font(PKFont.display(compact ? .subheadline : .headline, weight: .bold))
                    .foregroundStyle(PKColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !compact {
                    Text(tool.toolDescription)
                        .font(PKFont.body(.caption))
                        .foregroundStyle(PKColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                PKModeBadge(mode: tool.mode)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PKColors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 132 : 162, alignment: .topLeading)
        .pkCard(radius: PKRadius.md, background: PKColors.surface, border: PKColors.border, padding: compact ? 14 : 16)
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
    HStack(spacing: 12) {
        ToolCard(tool: ToolRegistry.all[0])
        ToolCard(tool: ToolRegistry.all[10], compact: true)
    }
    .padding()
    .background(PKColors.background)
    .environmentObject(FavoritesService.shared)
}
