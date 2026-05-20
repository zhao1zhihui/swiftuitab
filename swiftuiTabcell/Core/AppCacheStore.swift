import Foundation

nonisolated struct CacheKey: Hashable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }
}

nonisolated struct CachedData: Sendable {
    let data: Data
    let createdAt: Date
    let expiresAt: Date?

    func isExpired(at now: Date) -> Bool {
        guard let expiresAt else {
            return false
        }
        return now >= expiresAt
    }
}

/// 通用缓存协议。
/// 先固定读写边界，后续可以把内存实现替换成文件、SQLite、CoreData 或公司统一缓存组件。
nonisolated protocol CacheStore: Sendable {
    func loadData(for key: CacheKey, now: Date) async -> Data?
    func saveData(_ data: Data, for key: CacheKey, ttl: TimeInterval?, now: Date) async
    func removeData(for key: CacheKey) async
    func removeAll() async
}

/// 空缓存用于默认参数和不需要离线的场景。
/// 业务显式传入真实 CacheStore 后，Repository 才会拥有降级读取能力。
nonisolated struct NullCacheStore: CacheStore {
    func loadData(for key: CacheKey, now: Date) async -> Data? {
        nil
    }

    func saveData(_ data: Data, for key: CacheKey, ttl: TimeInterval?, now: Date) async {}

    func removeData(for key: CacheKey) async {}

    func removeAll() async {}
}

/// 内存缓存实现。
/// actor 负责串行化读写，适合 Preview、单测、短生命周期接口缓存和开发环境离线兜底。
actor InMemoryCacheStore: CacheStore {
    private var storage: [CacheKey: CachedData] = [:]

    func loadData(for key: CacheKey, now: Date) async -> Data? {
        guard let entry = storage[key] else {
            return nil
        }

        if entry.isExpired(at: now) {
            storage[key] = nil
            return nil
        }

        return entry.data
    }

    func saveData(_ data: Data, for key: CacheKey, ttl: TimeInterval?, now: Date) async {
        let expiresAt = ttl.map { now.addingTimeInterval($0) }
        storage[key] = CachedData(data: data, createdAt: now, expiresAt: expiresAt)
    }

    func removeData(for key: CacheKey) async {
        storage[key] = nil
    }

    func removeAll() async {
        storage.removeAll()
    }
}
