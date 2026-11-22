// xcode: set sdk=iOS

import SwiftUI

/// Displays actual recently used tools and latest processed files from `HistoryService`.
struct RecentView: View {
    @EnvironmentObject private var history: HistoryService
    @EnvironmentObject private var registry: ToolRegistryService

    private var recentTools: [Tool] {
        history.recentTools(from: registry.tools)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if recentTools.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PKColors.brand)
                            .frame(width: 34, height: 34)
                            .background(PKColors.brandSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your workspace is clean")
                                .font(PKFont.body(.subheadline, weight: .semibold))
                                .foregroundStyle(PKColors.textPrimary)
                            Text("Tools you open or run will appear right here for 1-tap relaunch.")
                                .font(PKFont.body(.caption))
                                .foregroundStyle(PKColors.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .pkInsetCard(radius: PKRadius.md, padding: 14)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recentTools) { tool in
                            NavigationLink(value: tool) {
                                ToolCard(tool: tool, compact: true)
                                    .frame(width: 172)
                            }
                            .buttonStyle(PKPressButtonStyle())
                        }
                    }
                    .padding(.vertical, 2)
                }

                if let latest = history.items.first {
                    HStack(spacing: 10) {
                        Image(systemName: latest.statusRaw == ProcessingStatus.completed.rawValue
                              ? "checkmark.circle.fill"
                              : "exclamationmark.circle.fill")
                            .foregroundStyle(latest.statusRaw == ProcessingStatus.completed.rawValue
                                             ? PKColors.success
                                             : PKColors.error)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Last run: \(latest.toolName)")
                                .font(PKFont.body(.caption, weight: .semibold))
                                .foregroundStyle(PKColors.textPrimary)
                                .lineLimit(1)
                            Text("\(latest.inputFileName) · \(latest.createdAt.formatted(date: .omitted, time: .shortened))")
                                .font(PKFont.mono(.caption2, weight: .regular))
                                .foregroundStyle(PKColors.textMuted)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        if latest.fileSize > 0 {
                            Text(ByteCountFormatter.string(fromByteCount: latest.fileSize, countStyle: .file))
                                .font(PKFont.mono(.caption2, weight: .semibold))
                                .foregroundStyle(PKColors.textSecondary)
                        }
                    }
                    .pkInsetCard(radius: PKRadius.sm, padding: 10)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecentView()
            .padding()
            .environmentObject(HistoryService.shared)
            .environmentObject(ToolRegistryService.shared)
            .environmentObject(FavoritesService.shared)
    }
}
