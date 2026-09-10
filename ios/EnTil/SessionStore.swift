import Foundation
import Security

/// Credentials never enter UserDefaults, logs, URLs, or analytics.
enum SessionStore {
    private static let service = "dev.adrez.entil.session"
    static func load() throws -> GuestSession? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "installation",
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw StoreError.keychain(status) }
        return try JSONDecoder().decode(GuestSession.self, from: data)
    }
    static func save(_ session: GuestSession) throws {
        let data = try JSONEncoder().encode(session)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "installation"]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw StoreError.keychain(added) }
        } else if status != errSecSuccess { throw StoreError.keychain(status) }
    }
    enum StoreError: LocalizedError {
        case keychain(OSStatus)
        var errorDescription: String? { "Din iPhone kunne ikke gemme forbindelsen sikkert. Prøv igen." }
    }
}
