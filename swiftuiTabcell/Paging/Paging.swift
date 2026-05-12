import Foundation

struct PagingState {
    var page: Int = 0
    var pageSize: Int = 10
    var hasMore: Bool = true
}

@MainActor
protocol PagingViewModel: AnyObject {
    associatedtype Item
    var items: [Item] { get set }
    var paging: PagingState { get set }
    func fetch(page: Int, pageSize: Int) async -> APIResult<PageResult<Item>>
}

@MainActor
extension PagingViewModel {
    @discardableResult
    func refresh() async -> APIResult<[Item]> {
        let currentPaging = paging
        let result = await fetch(page: 0, pageSize: paging.pageSize)
        guard !Task.isCancelled else { return .failure(.cancelled) }
        switch result {
        case .success(let pageResult):
            items = pageResult.items
            paging.page = pageResult.page
            paging.pageSize = pageResult.pageSize
            paging.hasMore = pageResult.hasMore
            return .success(items)
        case .failure(let error):
            paging = currentPaging
            return .failure(error)
        }
    }

    @discardableResult
    func loadMore() async -> APIResult<[Item]> {
        guard paging.hasMore else { return .success(items) }
        let nextPage = paging.page + 1
        let result = await fetch(page: nextPage, pageSize: paging.pageSize)
        guard !Task.isCancelled else { return .failure(.cancelled) }
        switch result {
        case .success(let pageResult):
            paging.page = nextPage
            items.append(contentsOf: pageResult.items)
            paging.hasMore = pageResult.hasMore
            return .success(items)
        case .failure(let error):
            return .failure(error)
        }
    }
}
