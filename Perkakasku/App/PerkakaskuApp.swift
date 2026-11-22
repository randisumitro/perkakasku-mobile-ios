// xcode: set sdk=iOS

import SwiftUI
import SwiftData

@main
struct PerkakaskuApp: App {
    @StateObject private var auth = AuthService.shared
    @StateObject private var registry = ToolRegistryService.shared
    @StateObject private var api = APIService.shared
    @StateObject private var pdf = PDFService.shared
    @StateObject private var image = ImageService.shared
    @StateObject private var history = HistoryService.shared
    @StateObject private var favorites = FavoritesService.shared
    @StateObject private var settings = AppSettingsService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(registry)
                .environmentObject(api)
                .environmentObject(pdf)
                .environmentObject(image)
                .environmentObject(history)
                .environmentObject(favorites)
                .environmentObject(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(PKColors.brand)
                .modelContainer(SwiftDataStack.shared.container)
        }
    }
}
