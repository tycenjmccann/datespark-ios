import Foundation
import Security

/// Service for securely storing and retrieving authentication tokens from the iOS Keychain.
///
/// All token storage uses kSecClassGenericPassword with the app's bundle identifier as the service name.
final class KeychainService: Sendable {

    static let shared = KeychainService()

    private let service = "com.datespark.auth"

    private init() {}

    // MARK: - Keys

    enum Key: String, CaseIterable, Sendable {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }

    // MARK: - Public API

    /// Save a token to the Keychain.
    func save(_ value: String, for key: Key) throws {
        let data = Data(value.utf8)

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieve a token from the Keychain.
    func retrieve(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Delete a specific token from the Keychain.
    func delete(for key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Delete ALL tokens stored by this service from the Keychain.
    /// Used during logout to ensure complete auth artifact clearance.
    func deleteAll() {
        for key in Key.allCases {
            delete(for: key)
        }
    }

    // MARK: - Errors

    enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Keychain save failed with status: \(status)"
            }
        }
    }
}
