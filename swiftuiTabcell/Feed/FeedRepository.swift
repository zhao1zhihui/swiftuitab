import Foundation

nonisolated private struct LocalFeedEnvelope<Item: Codable>: Codable {
    let code: Int
    let message: String
    let data: LocalFeedPage<Item>?
}

nonisolated private struct LocalFeedPage<Item: Codable>: Codable {
    let items: [Item]
}

/// Feature 层依赖仓库协议，而不是具体网络实现。
/// 后续单测、Preview 或离线模式都可以替换这个协议。
nonisolated protocol FeedRepositoryProtocol {
    func fetchFeed(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedItem>>
    func fetchFeedRaw(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedRaw>>
}

/// Feed 数据仓库负责把网络返回的 Data 解成业务分页结果。
/// ViewModel 不应该知道 envelope、分页切片和 DTO 解码细节。
nonisolated final class FeedRepository: FeedRepositoryProtocol {
    private let networkService: NetworkService
    private let cacheStore: any CacheStore
    private let clock: any AppClock
    private let cacheTTL: TimeInterval

    init(networkService: NetworkService,
         cacheStore: any CacheStore = NullCacheStore(),
         clock: any AppClock = SystemAppClock(),
         cacheTTL: TimeInterval = 5 * 60) {
        self.networkService = networkService
        self.cacheStore = cacheStore
        self.clock = clock
        self.cacheTTL = cacheTTL
    }

    func fetchFeed(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedItem>> {
        let result = await networkService.request(.feed(page: page, pageSize: pageSize))
        switch result {
        case .success(let data):
            await cacheStore.saveData(data, for: cacheKey(page: page, pageSize: pageSize), ttl: cacheTTL, now: clock.now)
            return makePageResult(from: data, itemType: FeedItem.self, page: page, pageSize: pageSize)
        case .failure(let error):
            // 网络失败时尝试读缓存，给首页这类列表一个基础离线兜底；是否展示“离线数据”可继续扩展到展示模型。
            if let cachedData = await cacheStore.loadData(for: cacheKey(page: page, pageSize: pageSize), now: clock.now) {
                return makePageResult(from: cachedData, itemType: FeedItem.self, page: page, pageSize: pageSize)
            }
            return .failure(error)
        }
    }

    func fetchFeedRaw(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedRaw>> {
        let result = await networkService.request(.feed(page: page, pageSize: pageSize))
        switch result {
        case .success(let data):
            await cacheStore.saveData(data, for: cacheKey(page: page, pageSize: pageSize), ttl: cacheTTL, now: clock.now)
            return makePageResult(from: data, itemType: FeedRaw.self, page: page, pageSize: pageSize)
        case .failure(let error):
            if let cachedData = await cacheStore.loadData(for: cacheKey(page: page, pageSize: pageSize), now: clock.now) {
                return makePageResult(from: cachedData, itemType: FeedRaw.self, page: page, pageSize: pageSize)
            }
            return .failure(error)
        }
    }

    private func cacheKey(page: Int, pageSize: Int) -> CacheKey {
        CacheKey("feed.page.\(page).size.\(pageSize)")
    }

    /// 当前 mock 接口一次返回全量 items，这里按 page/pageSize 切片，模拟真实分页接口。
    private func makePageResult<Item: Codable>(from data: Data,
                                               itemType: Item.Type,
                                               page: Int,
                                               pageSize: Int) -> APIResult<PageResult<Item>> {
        do {
            _ = itemType
            let response = try JSONDecoder().decode(LocalFeedEnvelope<Item>.self, from: data)
            guard response.code == 0 else {
                return .failure(.server(code: response.code, message: response.message))
            }
            guard let allItems = response.data?.items else {
                return .failure(.emptyData)
            }
            let startIndex = page * pageSize
            guard startIndex < allItems.count else {
                return .success(PageResult(items: [], page: page, pageSize: pageSize, hasMore: false))
            }
            let endIndex = min(startIndex + pageSize, allItems.count)
            let pagedItems = Array(allItems[startIndex..<endIndex])
            return .success(
                PageResult(
                    items: pagedItems,
                    page: page,
                    pageSize: pageSize,
                    hasMore: endIndex < allItems.count
                )
            )
        } catch {
            return .failure(.decoding(error.localizedDescription))
        }
    }
}
