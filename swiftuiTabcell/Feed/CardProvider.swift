import Foundation

@MainActor
protocol CardProvider {
    func loadItems(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedRow>>
}

/// Provider 是 Repository 到 RowModel 的适配层。
/// 这样接口模型和 UI 行模型不会互相污染，卡片事件也可以统一在 ViewModel 绑定。
@MainActor
final class EnumCardProvider: CardProvider {
    private let repository: FeedRepositoryProtocol

    init(repository: FeedRepositoryProtocol) {
        self.repository = repository
    }

    func loadItems(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedRow>> {
        let result = await repository.fetchFeed(page: page, pageSize: pageSize)
        return result.map { pageResult in
            pageResult.mapItems { item in
                item.makeRow()
            }
        }
    }
}
