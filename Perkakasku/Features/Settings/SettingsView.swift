// xcode: set sdk=iOS

import SwiftUI

/// App preferences, Guest Session status, Docker backend configuration, and cache controls.
/// Preserves guest mode cleanly and never redirects users to AuthView.
struct SettingsView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var settings: AppSettingsService
    @EnvironmentObject private var history: HistoryService

    @State private var selectedEnv: APIEnvironment = APIConfig.environment
    @State private var customURLText: String = APIConfig.customURLOverride ?? ""
    @State private var urlFeedback: String?
    @State private var confirmClearCache = false
    @State private var confirmClearHistory = false
    @State private var showingPlans = false

    var body: some View {
        NavigationStack {
            ZStack {
                PKStudioBackdrop(showGrid: false)

                Form {
                    guestSessionSection
                    appearanceSection
                    backendSection
                    storageSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Settings")
            .onAppear {
                settings.refreshStorageSize()
                selectedEnv = APIConfig.environment
                customURLText = APIConfig.customURLOverride ?? ""
            }
            .confirmationDialog("Delete all locally exported files?", isPresented: $confirmClearCache, titleVisibility: .visible) {
                Button("Clear Cached Exports", role: .destructive) {
                    settings.clearCache()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears temporary and exported outputs created by tools.")
            }
            .confirmationDialog("Clear all processing history?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) {
                    history.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingPlans) {
                PremiumView()
            }
        }
    }

    private var guestSessionSection: some View {
        Section {
            HStack(spacing: 12) {
                PKLogoMark(size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(auth.effectiveDisplayName)
                            .font(PKFont.display(.headline, weight: .bold))
                            .foregroundStyle(PKColors.textPrimary)
                        PKTagBadge(text: "Open Access", icon: "checkmark.seal.fill", tone: .success)
                    }
                    Text("Instant access to all 21 tools without requiring account login.")
                        .font(PKFont.body(.caption))
                        .foregroundStyle(PKColors.textSecondary)
                }
            }
            .padding(.vertical, 4)

            Button {
                showingPlans = true
            } label: {
                Label("Compare Sandbox Plans & Quotas", systemImage: "crown.fill")
                    .foregroundStyle(PKColors.brand)
            }
        } header: {
            Text("Workspace Access")
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("Theme", selection: $settings.appearance) {
                ForEach(AppAppearance.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Appearance")
        } footer: {
            Text("Warm Alabaster in Light Mode, Obsidian Espresso in Dark Mode — matching perkakasku.cloud.")
        }
    }

    private var backendSection: some View {
        Section {
            Picker("Environment", selection: $selectedEnv) {
                ForEach(APIEnvironment.allCases) { env in
                    Text(env.label).tag(env)
                }
            }
            .onChange(of: selectedEnv) { _, newValue in
                APIConfig.environment = newValue
                urlFeedback = nil
                Task { await settings.refreshBackendStatus() }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Backend URL (Optional)")
                    .font(PKFont.body(.caption, weight: .semibold))
                    .foregroundStyle(PKColors.textSecondary)

                HStack(spacing: 8) {
                    TextField("http://127.0.0.1:4000", text: $customURLText)
                        .font(PKFont.mono(.footnote, weight: .regular))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .padding(9)
                        .background(PKColors.backgroundInset, in: RoundedRectangle(cornerRadius: 8))

                    Button("Apply") {
                        applyCustomURL()
                    }
                    .buttonStyle(PKPillButtonStyle(variant: .ink, compact: true))
                }

                if let urlFeedback {
                    Text(urlFeedback)
                        .font(PKFont.body(.caption2))
                        .foregroundStyle(PKColors.brand)
                }
            }
            .padding(.vertical, 4)

            HStack {
                Text("Active Endpoint")
                    .foregroundStyle(PKColors.textSecondary)
                Spacer()
                Text(APIConfig.baseURL.absoluteString)
                    .font(PKFont.mono(.caption, weight: .medium))
                    .foregroundStyle(PKColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack {
                Text("Connectivity")
                    .foregroundStyle(PKColors.textSecondary)
                Spacer()
                HStack(spacing: 6) {
                    PKLiveDot(color: settings.backendStatus.isOnline ? PKColors.success : PKColors.warning)
                    Text(settings.backendStatus.label)
                        .font(PKFont.mono(.caption, weight: .semibold))
                        .foregroundStyle(PKColors.textPrimary)
                }
            }

            Button {
                PKHaptics.impact(.light)
                Task { await settings.refreshBackendStatus() }
            } label: {
                HStack {
                    Label("Test Backend Health", systemImage: "network")
                    Spacer()
                    if case .checking = settings.backendStatus {
                        ProgressView().controlSize(.small)
                    }
                }
            }
        } header: {
            Text("Docker & Cloud Sandbox")
        } footer: {
            Text("Server-backed tools (PDF Compression, PDF -> Word/Excel, Word -> PDF) connect here. On-device tools work even when offline.")
        }
    }

    private var storageSection: some View {
        Section {
            HStack {
                Text("Cached Output Files")
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: settings.cachedStorageBytes, countStyle: .file))
                    .font(PKFont.mono(.subheadline, weight: .semibold))
                    .foregroundStyle(PKColors.textSecondary)
            }

            HStack {
                Text("History Entries")
                Spacer()
                Text("\(history.totalProcessedCount)")
                    .font(PKFont.mono(.subheadline, weight: .semibold))
                    .foregroundStyle(PKColors.textSecondary)
            }

            Button("Clear Cached Exports", role: .destructive) {
                confirmClearCache = true
            }
            .disabled(settings.cachedStorageBytes == 0)

            Button("Clear History Log", role: .destructive) {
                confirmClearHistory = true
            }
            .disabled(history.items.isEmpty)
        } header: {
            Text("Storage & Privacy")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Application", value: "Perkakasku iOS")
            LabeledContent("Version", value: "1.0")
            LabeledContent("Registered Tools", value: "\(ToolRegistry.all.count)")
            LabeledContent("Local-Only Tools", value: "\(ToolRegistry.all.filter(\.isLocalOnly).count)")
        }
    }

    private func applyCustomURL() {
        let trimmed = customURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            APIConfig.customURLOverride = nil
            urlFeedback = "Cleared override; using \(APIConfig.environment.defaultURLString)."
        } else if let parsed = URL(string: trimmed), parsed.scheme == "http" || parsed.scheme == "https" {
            APIConfig.customURLOverride = trimmed
            urlFeedback = "Applied custom URL: \(trimmed)"
        } else {
            urlFeedback = "Please enter a valid http:// or https:// URL."
            PKHaptics.error()
            return
        }
        PKHaptics.success()
        Task { await settings.refreshBackendStatus() }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService.shared)
        .environmentObject(AppSettingsService.shared)
        .environmentObject(HistoryService.shared)
}
