// xcode: set sdk=iOS

import SwiftUI
import UIKit

/// Root flow: App Launch -> Animated SplashView -> MainTabView (Guest Mode active; never redirects to AuthView).
struct RootView: View {
    @EnvironmentObject var settings: AppSettingsService
    @EnvironmentObject var auth: AuthService

    @State private var showingSplash = true

    init() {
        configureSystemAppearance()
    }

    var body: some View {
        ZStack {
            MainTabView()
                .opacity(showingSplash ? 0 : 1)
                .scaleEffect(showingSplash ? 0.985 : 1.0)
                .accessibilityHidden(showingSplash)

            if showingSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showingSplash = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.02)))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showingSplash)
        .task {
            await settings.refreshBackendStatus()
        }
    }

    private func configureSystemAppearance() {
        let primaryInk = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0xF6 / 255, green: 0xF4 / 255, blue: 0xEF / 255, alpha: 1.0)
                : UIColor(red: 0x18 / 255, green: 0x16 / 255, blue: 0x14 / 255, alpha: 1.0)
        }

        let standardNav = UINavigationBarAppearance()
        standardNav.configureWithDefaultBackground()
        standardNav.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x12 / 255, green: 0x11 / 255, blue: 0x10 / 255, alpha: 0.94)
                : UIColor(red: 0xF6 / 255, green: 0xF4 / 255, blue: 0xEF / 255, alpha: 0.94)
        }
        standardNav.titleTextAttributes = [.foregroundColor: primaryInk]
        standardNav.largeTitleTextAttributes = [.foregroundColor: primaryInk]
        standardNav.shadowColor = UIColor.label.withAlphaComponent(0.08)

        let scrollEdgeNav = UINavigationBarAppearance()
        scrollEdgeNav.configureWithTransparentBackground()
        scrollEdgeNav.titleTextAttributes = [.foregroundColor: primaryInk]
        scrollEdgeNav.largeTitleTextAttributes = [.foregroundColor: primaryInk]

        UINavigationBar.appearance().standardAppearance = standardNav
        UINavigationBar.appearance().compactAppearance = standardNav
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdgeNav

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x18 / 255, green: 0x16 / 255, blue: 0x14 / 255, alpha: 0.96)
                : UIColor(red: 0xFF / 255, green: 0xFF / 255, blue: 0xFF / 255, alpha: 0.96)
        }
        tabBarAppearance.shadowColor = UIColor.label.withAlphaComponent(0.08)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

private struct MainTabView: View {
    @EnvironmentObject var settings: AppSettingsService

    var body: some View {
        TabView(selection: $settings.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(MainTab.home)

            ToolCatalogView()
                .tabItem {
                    Label("Tools", systemImage: "square.grid.2x2.fill")
                }
                .tag(MainTab.tools)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(MainTab.history)

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
                .tag(MainTab.favorites)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(MainTab.settings)
        }
        .tint(PKColors.brand)
        .onChange(of: settings.selectedTab) { _, _ in
            PKHaptics.selection()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthService.shared)
        .environmentObject(ToolRegistryService.shared)
        .environmentObject(APIService.shared)
        .environmentObject(PDFService.shared)
        .environmentObject(ImageService.shared)
        .environmentObject(HistoryService.shared)
        .environmentObject(FavoritesService.shared)
        .environmentObject(AppSettingsService.shared)
}

