// xcode: set sdk=iOS

import SwiftUI

/// Local processing log backed by SwiftData (`HistoryService.shared`).
struct HistoryView: View {
    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case completed = "Completed"
        case failed = "Failed"

        var id: String { rawValue }
    }

    private struct PreviewItem: Identifiable {
        let id = UUID()
        let url: URL
        let title: String
    }

    @EnvironmentObject private var history: HistoryService
    @EnvironmentObject private var settings: AppSettingsService

    @State private var searchText = ""
    @State private var statusFilter: StatusFilter = .all
    @State private var confirmClear = false
    @State private var previewItem: PreviewItem?

    private var filteredItems: [ProcessedItemModel] {
        history.items.filter { item in
            let matchesStatus: Bool = switch statusFilter {
            case .all: true
            case .completed: item.statusRaw == ProcessingStatus.completed.rawValue
            case .failed: item.statusRaw == ProcessingStatus.failed.rawValue
            }
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = q.isEmpty
                || item.toolName.localizedCaseInsensitiveContains(q)
                || item.inputFileName.localizedCaseInsensitiveContains(q)
                || (item.outputFileName?.localizedCaseInsensitiveContains(q) ?? false)
            return matchesStatus && matchesQuery
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PKStudioBackdrop(showGrid: false)

                Group {
                    if history.items.isEmpty {
                        EmptyStateView(
                            icon: "clock.arrow.circlepath",
                            title: "No processing history yet",
                            subtitle: "Files you compress, merge, convert, scan, or sign appear here with quick preview & share.",
                            actionTitle: "Explore 21 Tools",
                            actionIcon: "square.grid.2x2.fill"
                        ) {
                            settings.openTools(category: nil)
                        }
                        .padding(.horizontal, 16)
                    } else {
                        List {
                            Section {
                                Picker("Status", selection: $statusFilter) {
                                    ForEach(StatusFilter.allCases) { f in
                                        Text(f.rawValue).tag(f)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                            }

                            if filteredItems.isEmpty {
                                EmptyStateView(
                                    icon: "magnifyingglass",
                                    title: "No matching records",
                                    subtitle: "Try clearing the filter or search phrase."
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            } else {
                                ForEach(filteredItems) { item in
                                    HistoryRowView(item: item) { url, title in
                                        previewItem = PreviewItem(url: url, title: title)
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            history.delete(item)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .searchable(text: $searchText, prompt: "Filter by tool or file name")
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !history.items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", role: .destructive) {
                            confirmClear = true
                        }
                        .foregroundStyle(PKColors.error)
                    }
                }
            }
            .confirmationDialog("Clear all local processing history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear All History", role: .destructive) {
                    history.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all saved activity records from this device.")
            }
            .sheet(item: $previewItem) { item in
                QuickLookPreviewSheet(url: item.url, title: item.title)
            }
            .onAppear {
                history.reload()
            }
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(HistoryService.shared)
        .environmentObject(AppSettingsService.shared)
}
