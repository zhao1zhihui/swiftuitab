import Foundation
import Security

nonisolated enum TokenStoreError: Error, LocalizedError, Sendable {
    case invalidData
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Token 数据格式错误"
        case .keychainFailure(let status):
            return "Keychain 操作失败: \(status)"
        }
    }
}

/// token 存储协议。
/// AppSession 只关心“保存/读取/清空 token”，不直接依赖 Keychain，方便单测和 Preview 使用内存实现。
nonisolated protocol TokenStore: Sendable {
    func loadTokens() async throws -> AuthTokens?
    func saveTokens(_ tokens: AuthTokens) async throws
    func clearTokens() async throws
}

/// 内存 token 存储。
/// actor 自己负责串行化读写；只适合 development、单元测试和 Preview。
actor InMemoryTokenStore: TokenStore {
    private var tokens: AuthTokens?

    init(tokens: AuthTokens? = nil) {
        self.tokens = tokens
    }

    func loadTokens() async throws -> AuthTokens? {
        tokens
    }

    func saveTokens(_ tokens: AuthTokens) async throws {
        self.tokens = tokens
    }

    func clearTokens() async throws {
        tokens = nil
    }
}

/// Keychain token 存储。
/// 这里把系统安全存储封装在 Infrastructure 边界内，业务层不需要知道 SecItem 查询细节。
nonisolated final class KeychainTokenStore: TokenStore, @unchecked Sendable {
    private let service: String
    private let account: String

    init(service: String = "qweqe.swiftuiTabcell.auth",
         account: String = "authTokens") {
        self.service = service
        self.account = account
    }

    func loadTokens() async throws -> AuthTokens? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw TokenStoreError.keychainFailure(status)
        }

        guard let data = result as? Data else {
            throw TokenStoreError.invalidData
        }

        return try JSONDecoder().decode(AuthTokens.self, from: data)
    }

    func saveTokens(_ tokens: AuthTokens) async throws {
        let data = try JSONEncoder().encode(tokens)
        let query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw TokenStoreError.keychainFailure(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw TokenStoreError.keychainFailure(addStatus)
        }
    }

    func clearTokens() async throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStoreError.keychainFailure(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
