import Foundation

/// Lightweight API client for authentication endpoints.
///
/// Handles the server-side logout call with proper timeout and error handling.
/// Per security requirements (TEAM-141), the server must revoke tokens.
actor APIClient {

    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let logoutTimeout: TimeInterval = 10 // 10 second timeout per spec

    private init() {
        // Configure base URL — in production, read from environment/config
        self.baseURL = URL(string: "https://api.datespark.app/api/v1")!

        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Logout

    /// Errors that can occur during API calls.
    enum APIError: Error, LocalizedError, Sendable {
        case invalidURL
        case networkError(String)
        case serverError(Int)
        case timeout

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .networkError(let message):
                return "Network error: \(message)"
            case .serverError(let code):
                return "Server error: \(code)"
            case .timeout:
                return "Request timed out"
            }
        }
    }

    /// Call the server-side logout endpoint to revoke the session.
    ///
    /// Per TEAM-141 security requirements:
    /// - POST /api/v1/auth/logout with the access token
    /// - Server revokes refresh token and blocklists access token JTI
    /// - 401 response is treated as success (session already expired)
    /// - Timeout after 10 seconds
    ///
    /// - Parameter accessToken: The current access token to include in the Authorization header.
    /// - Throws: `APIError` if the request fails (caller should handle gracefully).
    func logout(accessToken: String) async throws {
        let url = baseURL.appendingPathComponent("auth/logout")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = logoutTimeout

        do {
            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Invalid response")
            }

            // 401 means session already expired — treat as success
            // 200-299 is normal success
            let statusCode = httpResponse.statusCode
            if statusCode == 401 || (200...299).contains(statusCode) {
                return // Success
            }

            throw APIError.serverError(statusCode)
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }

    /// Clear the shared URL session's cookie storage.
    func clearCookies() {
        if let cookies = session.configuration.httpCookieStorage?.cookies {
            for cookie in cookies {
                session.configuration.httpCookieStorage?.deleteCookie(cookie)
            }
        }
        // Also clear shared cookie storage
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
}
