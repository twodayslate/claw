//
//  LobstersCredentialStore.swift
//  claw
//

import Foundation
import Security

struct LobstersEntitlementSnapshot: Codable, Equatable, Sendable {
    let isEntitled: Bool
    let validUntil: Date?

    func allowsAuthenticatedRequests(at date: Date = Date()) -> Bool {
        guard isEntitled else {
            return false
        }
        return validUntil.map { $0 > date } ?? true
    }
}

enum LobstersEntitlementStore {
    private static let suiteName = "group.com.twodayslate.claw"
    private static let key = "lobsters-verified-pro-entitlement-v1"

    static var allowsAuthenticatedRequests: Bool {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(
                LobstersEntitlementSnapshot.self,
                from: data
              ) else {
            return false
        }
        return snapshot.allowsAuthenticatedRequests()
    }

    static func update(isEntitled: Bool, validUntil: Date?) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(
                LobstersEntitlementSnapshot(
                    isEntitled: isEntitled,
                    validUntil: validUntil
                )
              ) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

struct StoredLobstersCookie: Codable, Equatable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expiresDate: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool

    init?(_ cookie: HTTPCookie, for url: URL) {
        guard cookie.name == LobstersCredentialStore.cookieName,
              let host = url.host?.lowercased() else {
            return nil
        }

        let cookieDomain = cookie.domain
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        guard cookieDomain == host else {
            return nil
        }

        name = cookie.name
        value = cookie.value
        domain = cookieDomain
        path = cookie.path.isEmpty ? "/" : cookie.path
        expiresDate = cookie.expiresDate
        isSecure = cookie.isSecure
        isHTTPOnly = cookie.isHTTPOnly
    }

    var isExpired: Bool {
        expiresDate.map { $0 <= Date() } ?? false
    }

    var requestHeaderValue: String {
        "\(name)=\(value)"
    }

    func makeCookie() -> HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path
        ]
        if let expiresDate {
            properties[.expires] = expiresDate
        }
        if isSecure {
            properties[.secure] = "TRUE"
        }
        if isHTTPOnly {
            properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE"
        }
        return HTTPCookie(properties: properties)
    }
}

struct LobstersCredentialStore: Sendable {
    static let cookieName = "lobster_trap"

    private let service: String
    private let accessGroup: String?

    init(
        service: String = "com.twodayslate.claw.lobsters-session",
        accessGroup: String? = LobstersCredentialStore.bundleAccessGroup
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    func loadCookie(for url: URL) throws -> StoredLobstersCookie? {
        var query = baseQuery(for: url)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        let cookie: StoredLobstersCookie
        do {
            cookie = try JSONDecoder().decode(StoredLobstersCookie.self, from: data)
        } catch {
            // An older or damaged payload cannot become readable by retrying.
            // Remove it so the session can recover to signed out and log in again.
            try deleteCookie(for: url)
            return nil
        }
        if cookie.isExpired {
            try? deleteCookie(for: url)
            return nil
        }
        return cookie
    }

    func saveCookie(_ cookie: HTTPCookie, for url: URL) throws {
        guard let storedCookie = StoredLobstersCookie(cookie, for: url) else {
            throw KeychainError.invalidCookie
        }

        let data = try JSONEncoder().encode(storedCookie)
        var attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let query = baseQuery(for: url)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError(status: updateStatus)
        }

        attributes.merge(query) { current, _ in current }
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError(status: addStatus)
        }
    }

    func deleteCookie(for url: URL) throws {
        let status = SecItemDelete(baseQuery(for: url) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private func baseQuery(for url: URL) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: url)
        ]

        if let accessGroup,
           !accessGroup.isEmpty,
           !accessGroup.contains("$(") {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    private static var bundleAccessGroup: String? {
        Bundle.main.object(
            forInfoDictionaryKey: "LobstersKeychainAccessGroup"
        ) as? String
    }

    private func account(for url: URL) -> String {
        let host = url.host?.lowercased() ?? "unknown"
        if let port = url.port {
            return "\(host):\(port)"
        }
        return host
    }
}

enum KeychainError: LocalizedError {
    case invalidCookie
    case invalidData
    case status(OSStatus)

    init(status: OSStatus) {
        self = .status(status)
    }

    var errorDescription: String? {
        switch self {
        case .invalidCookie:
            return "The Lobsters session cookie did not match the configured server."
        case .invalidData:
            return "The Lobsters session stored in Keychain could not be read."
        case .status(let status):
            let message = SecCopyErrorMessageString(status, nil) as String?
            return message ?? "Keychain returned error \(status)."
        }
    }
}
