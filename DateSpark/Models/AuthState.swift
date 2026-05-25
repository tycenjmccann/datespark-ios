import Foundation

/// Represents the current authentication state of the application.
enum AuthState: Sendable, Equatable {
    /// User is not authenticated — show login screen.
    case unauthenticated

    /// Authentication is being verified (e.g., on app launch).
    case loading

    /// User is authenticated with a valid session.
    case authenticated(User)

    /// Logout is in progress.
    case loggingOut

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }

    var currentUser: User? {
        if case .authenticated(let user) = self { return user }
        return nil
    }
}
