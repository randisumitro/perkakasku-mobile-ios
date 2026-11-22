import Foundation
import SwiftUI

/// Persists favorited tool slugs locally for immediate guest-mode access.
@MainActor
final class FavoritesService: ObservableObject {
    static let shared = FavoritesService()

    @Published private(set) var favoriteSlugs: [String] = []

    private let storageKey = "pk_favorite_tool_slugs"

    private init() {
        self.favoriteSlugs = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
    }

    func isFavorite(_ slug: String) -> Bool {
        favoriteSlugs.contains(slug)
    }

    func toggle(_ slug: String) {
        if let idx = favoriteSlugs.firstIndex(of: slug) {
            favoriteSlugs.remove(at: idx)
        } else {
            favoriteSlugs.insert(slug, at: 0)
        }
        UserDefaults.standard.set(favoriteSlugs, forKey: storageKey)
        PKHaptics.selection()
    }

    func favoriteTools(from allTools: [Tool]) -> [Tool] {
        favoriteSlugs.compactMap { slug in
            allTools.first(where: { $0.slug == slug })
        }
    }

    func clearAll() {
        favoriteSlugs.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
