// xcode: set sdk=iOS

import SwiftUI

/// Unified workbench container mirroring the website's ToolPage/ToolLayout structure.
/// Renders tool header metadata, privacy badge, live interactive workspace, and related tools.
struct ToolDetailView: View {
    let tool: Tool

    @EnvironmentObject private var favorites: FavoritesService
    @EnvironmentObject private var history: HistoryService
    @EnvironmentObject private var registry: ToolRegistryService

    @State private var showToolInfo = false

    private var isFav: Bool { favorites.isFavorite(tool.slug) }

    private var relatedTools: [Tool] {
        tool.relatedSlugs.compactMap { registry.tool(slug: $0) }
    }

    var body: some View {
        ZStack {
            PKStudioBackdrop(showGrid: false)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    toolHeaderCard
                    ToolPrivacyBanner(mode: tool.mode, text: tool.privacySummary)

                    ToolWorkspaceRouter.workspace(for: tool)

                    if !relatedTools.isEmpty {
                        relatedSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(tool.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    PKHaptics.impact(.light)
                    showToolInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(PKColors.textSecondary)
                }
                .accessibilityLabel("Tool specifications")

                Button {
                    favorites.toggle(tool.slug)
                } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .foregroundStyle(isFav ? PKColors.brandVivid : PKColors.textSecondary)
                        .symbolEffect(.bounce, value: isFav)
                }
                .accessibilityLabel(isFav ? "Remove from favorites" : "Add to favorites")
                .accessibilityIdentifier("tool_favorite_button")
            }
        }
        .sheet(isPresented: $showToolInfo) {
            toolInfoSheet
        }
        .onAppear {
            history.markToolOpened(tool.slug)
        }
    }

    private var toolHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PKColors.brandSoft)
                        .frame(width: 48, height: 48)
                    Image(systemName: tool.iconName)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(PKColors.brand)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        PKTagBadge(text: tool.category.displayName, tone: .neutral)
                        PKModeBadge(mode: tool.mode)
                    }

                    Text(tool.name)
                        .font(PKFont.display(.title3, weight: .bold))
                        .foregroundStyle(PKColors.textPrimary)
                }

                Spacer(minLength: 0)
            }

            Text(tool.toolDescription)
                .font(PKFont.body(.subheadline))
                .foregroundStyle(PKColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PKColors.brand)
                Text(tool.inputHint)
                    .font(PKFont.mono(.caption2, weight: .medium))
                    .foregroundStyle(PKColors.textMuted)
            }
        }
        .pkCard(radius: PKRadius.md, background: PKColors.surface, border: PKColors.border, padding: 16)
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Next Workflow Steps",
                subtitle: "Tools commonly paired with \(tool.name)"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(relatedTools) { related in
                        NavigationLink(value: related) {
                            ToolCard(tool: related, compact: true)
                                .frame(width: 172)
                        }
                        .buttonStyle(PKPressButtonStyle())
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 6)
    }

    private var toolInfoSheet: some View {
        NavigationStack {
            List {
                Section("Capabilities") {
                    LabeledContent("Category", value: tool.category.displayName)
                    LabeledContent("Processing", value: tool.mode.displayLabel)
                    LabeledContent("Multi-file", value: tool.supportsMultipleFiles ? "Supported" : "Single item")
                    if let maxMB = tool.maxFileSizeMB {
                        LabeledContent("Max Upload Size", value: "\(maxMB) MB")
                    } else {
                        LabeledContent("Size Limit", value: "Limited by device memory")
                    }
                }

                Section("Input & Privacy") {
                    Text(tool.inputHint)
                        .font(PKFont.body(.subheadline))
                    Text(tool.privacySummary)
                        .font(PKFont.body(.footnote))
                        .foregroundStyle(PKColors.textSecondary)
                }
            }
            .navigationTitle(tool.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showToolInfo = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        ToolDetailView(tool: ToolRegistry.all[0])
            .environmentObject(FavoritesService.shared)
            .environmentObject(HistoryService.shared)
            .environmentObject(ToolRegistryService.shared)
            .environmentObject(APIService.shared)
            .environmentObject(PDFService.shared)
            .environmentObject(ImageService.shared)
    }
}
