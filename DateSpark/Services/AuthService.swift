import Foundation
import Observation

/// Central authentication service managing login state, token lifecycle, and logout.
///
/// This is the single source of truth for auth state in the app. Views observe
/// `authState` to determine what to render. The logout flow follows TEAM-141
/// security requirements for complete session invalidation.
@Observable
@MainActor
final class AuthService {

    // MARK: - State

    /// Current authentication state — drives root navigation.
    var authState: AuthState = .loading

    /// Error message to display (e.g., if logout API fails but local clear succeeds).
    var errorMessage: String?

    // MARK: - Dependencies

    private let keychain: KeychainService
    private let apiClient: APIClient

    // MARK: - Init

    init(
        keychain: KeychainService = .shared,
        apiClient: APIClient = .shared
    ) {
        self.keychain = keychain
        self.apiClient = apiClient
    }

    // MARK: - Public API

    /// Check stored credentials on app launch and restore session if valid.
    func checkAuthState() {
        if let accessToken = keychain.retrieve(for: .accessToken),
           !accessToken.isEmpty {
            // In production, validate token expiry here
            // For now, assume valid if present
            let user = loadCachedUser() ?? User(
                id: "current",
                email: "user@datespark.app",
                displayName: "DateSpark User",
                avatarURL: nil,
                createdAt: nil
            )
            authState = .authenticated(user)
        } else {
            authState = .unauthenticated
        }
    }

    /// Execute the complete logout flow.
    ///
    /// Per TEAM-141 security requirements, the flow is:
    /// 1. Set loading state (prevents double-tap)
    /// 2. Call server-side logout to revoke tokens
    /// 3. Clear ALL local auth artifacts regardless of server response
    /// 4. Transition to unauthenticated state (triggers navigation)
    ///
    /// If the server call fails (network error, timeout), we still clear
    /// local state and redirect — the server tokens will expire naturally.
    func logout() async {
        // Prevent re-entry
        guard authState != .loggingOut else { return }

        authState = .loggingOut
        errorMessage = nil

        // Step 1: Attempt server-side logout
        let accessToken = keychain.retrieve(for: .accessToken) ?? ""

        if !accessToken.isEmpty {
            do {
                try await apiClient.logout(accessToken: accessToken)
            } catch {
                // Server-side logout failed — log but continue with local cleanup
                // Per TEAM-141: "if server-side logout fails, still clear local state and redirect"
                print("[AuthService] Server logout failed: \(error.localizedDescription). Proceeding with local cleanup.")
            }
        }

        // Step 2: Clear ALL local auth artifacts (ALWAYS executes)
        clearAllLocalAuthState()

        // Step 3: Transition to unauthenticated (triggers navigation reactively)
        authState = .unauthenticated
    }

    // MARK: - Private

    /// Clear all local authentication artifacts.
    ///
    /// Per TEAM-141, must clear:
    /// - Keychain: access_token, refresh_token
    /// - UserDefaults: user_profile, any auth-related keys
    /// - HTTP cookies (session_id, csrf_token)
    /// - In-memory state (handled by authState transition)
    private func clearAllLocalAuthState() {
        // Clear Keychain tokens
        keychain.deleteAll()

        // Clear UserDefaults auth data
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "user_profile")
        defaults.removeObject(forKey: "last_login_date")
        defaults.removeObject(forKey: "session_metadata")
        defaults.synchronize()

        // Clear HTTP cookies
        Task {
            await apiClient.clearCookies()
        }

        // Clear shared cookie storage (belt and suspenders)
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }

        // Clear URLCache
        URLCache.shared.removeAllCachedResponses()
    }

    /// Load cached user profile from UserDefaults (if available).
    private func loadCachedUser() -> User? {
        guard let data = UserDefaults.standard.data(forKey: "user_profile") else {
            return nil
        }
        return try? JSONDecoder().decode(User.self, from: data)
    }
}
