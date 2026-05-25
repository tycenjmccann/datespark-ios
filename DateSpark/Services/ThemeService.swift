import SwiftUI
import Observation

/// Service managing the app's theme preference with UserDefaults persistence.
///
/// The service provides three modes:
/// - `.light`: Forces light appearance
/// - `.dark`: Forces dark appearance
/// - `.system`: Follows the OS setting (returns nil for preferredColorScheme)
///
/// Persistence: Uses UserDefaults to store the raw string value of the preference.
/// On init, reads from UserDefaults and defaults to `.system` if no value is stored.
@Observable
@MainActor
final class ThemeService {

    /// The user's selected theme preference. Persisted to UserDefaults on change.
    var preference: ThemePreference {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: Self.storageKey)
        }
    }

    /// The resolved color scheme to apply via `.preferredColorScheme()`.
    /// Returns `nil` when preference is `.system` to let iOS handle it.
    var resolvedColorScheme: ColorScheme? {
        preference.resolvedColorScheme
    }

    // MARK: - Private

    private static let storageKey = "themePreference"

    // MARK: - Init

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        self.preference = ThemePreference(rawValue: stored) ?? .system
    }
}
