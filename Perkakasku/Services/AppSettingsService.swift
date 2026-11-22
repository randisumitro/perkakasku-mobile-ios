import Foundation
import SwiftUI

enum MainTab: String, CaseIterable, Hashable {
    case home
    case tools
    case history
    case favorites
    case settings
}

enum BackendHealthStatus: Equatable, Sendable {
    case unknown
    case checking
    case online(latencyMs: Int, dbConnected: Bool)
    case unreachable(String)

    var label: String {
        switch self {
        case .unknown: return "Not Checked"
        case .checking: return "Checking…"
        case .online(let ms, let db):
            return db ? "Connected (\(ms) ms)" : "Reachable (\(ms) ms)"
        case .unreachable:
            return "Offline (Local Tools Ready)"
        }
    }

    var isOnline: Bool {
        if case .online = self { return true }
        return false
    }
}

/// Centralized app-wide preferences, backend diagnostics, and navigation coordination.
@MainActor
final class AppSettingsService: ObservableObject {
    static let shared = AppSettingsService()

    private let appearanceKey = "pk_app_appearance"

    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: appearanceKey)
        }
    }
    @Published var selectedTab: MainTab = .home
    @Published var catalogCategoryFilter: ToolCategory? = nil
    @Published var backendStatus: BackendHealthStatus = .unknown
    @Published var externalBgRemoveConfigured: Bool = false
    @Published var cachedStorageBytes: Int64 = 0
    @Published var availablePlans: [PublicPlan] = []

    private init() {
        let saved = UserDefaults.standard.string(forKey: appearanceKey)
        self.appearance = saved.flatMap { AppAppearance(rawValue: $0) } ?? .system
        refreshStorageSize()
    }

    func openTools(category: ToolCategory? = nil) {
        catalogCategoryFilter = category
        selectedTab = .tools
        PKHaptics.selection()
    }

    func refreshStorageSize() {
        cachedStorageBytes = LocalFileManager.shared.totalOutputsStorageBytes()
    }

    func clearCache() {
        LocalFileManager.shared.clearOutputsCache()
        refreshStorageSize()
        PKHaptics.success()
    }

    func refreshBackendStatus() async {
        backendStatus = .checking
        do {
            let (health, latency) = try await APIService.shared.checkHealth()
            let dbOK = (health.db ?? "").lowercased() == "connected"
            backendStatus = .online(latencyMs: latency, dbConnected: dbOK)

            if let caps = try? await APIService.shared.capabilities() {
                externalBgRemoveConfigured = caps.backgroundRemoveExternalConfigured ?? false
            }
            if let plans = try? await APIService.shared.fetchPublicPlans(), !plans.isEmpty {
                availablePlans = plans
            }
        } catch {
            backendStatus = .unreachable(error.localizedDescription)
        }
    }
}
