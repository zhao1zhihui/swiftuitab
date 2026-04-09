import Foundation

protocol CardProvider {
    func loadItems(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedRow>>
}

final class EnumCardProvider: CardProvider {
    private let repository = FeedRepository()

    func loadItems(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedRow>> {
        let result = await repository.fetchFeed(page: page, pageSize: pageSize)
        return result.map { pageResult in
            pageResult.mapItems { item in
                item.makeRow()
            }
        }
    }
}
