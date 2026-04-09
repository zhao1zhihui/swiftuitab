internal import SwiftUI
internal import Combine

@MainActor
final class FeedScreenViewModel: ObservableObject, PagingViewModel {
    enum ListState: Equatable {
        case content
        case empty(message: String)
        case error(message: String)
    }

    struct AlertMessage: Identifiable {
        let id = UUID()
        let message: String
    }

    typealias Item = FeedRow

    @Published var items: [FeedRow] = []
    @Published var listState: ListState = .content
    @Published var alertMessage: AlertMessage?
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var hasLoadedOnce = false

    var paging = PagingState(page: 0, pageSize: 10, hasMore: true)
    private let provider: CardProvider = EnumCardProvider()

    func fetch(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedRow>> {
        await provider.loadItems(page: page, pageSize: pageSize)
    }

    func refreshContent() async {
        if isLoadingMore || isRefreshing {
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        let result = await refresh()
        guard !Task.isCancelled else { return }
        applyRefresh(result)
        hasLoadedOnce = true
    }

    func loadMoreContent() async {
        if isRefreshing || isLoadingMore || !paging.hasMore {
            return
        }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let result = await loadMore()
        guard !Task.isCancelled else { return }
        applyLoadMore(result)
    }

    func loadMoreIfNeeded(currentItemID: String) async {
        guard currentItemID == items.last?.id else { return }
        await loadMoreContent()
    }

    func send(_ action: FeedAction) {
        switch action {
        case .tapTextTitle(let id):
            showEvent("action 事件: 点击了 Text title, id = \(id)")
        case .tapTextSubtitle(let id):
            showEvent("action 事件: 点击了 Text subtitle, id = \(id)")
        case .tapImageTitle(let id):
            showEvent("action 事件: 点击了 Image title, id = \(id)")
        case .tapImage(let id):
            showEvent("action 事件: 点击了 Image image, id = \(id)")
        case .tapImageURL(let id):
            showEvent("action 事件: 点击了 Image url, id = \(id)")
        case .tapActionTitle(let id):
            showEvent("action 事件: 点击了 Action title, id = \(id)")
        case .tapActionButton(let id):
            showEvent("action 事件: 点击了 Action button, id = \(id)")
        case .tapProfileName(let id):
            showEvent("action 事件: 点击了 Profile name, id = \(id)")
        case .tapProfileFollow(let id):
            showEvent("action 事件: 点击了 Profile follow, id = \(id)")
        case .tapProfileMessage(let id):
            showEvent("action 事件: 点击了 Profile message, id = \(id)")
        }
    }

    private func applyRefresh(_ result: APIResult<[FeedRow]>) {
        switch result {
        case .success(let items):
            listState = items.isEmpty ? .empty(message: "暂无数据") : .content
        case .failure(let error):
            if case .cancelled = error {
                return
            }
            if items.isEmpty {
                listState = .error(message: error.message)
            } else {
                alertMessage = AlertMessage(message: error.message)
            }
        }
    }

    private func applyLoadMore(_ result: APIResult<[FeedRow]>) {
        switch result {
        case .success:
            listState = items.isEmpty ? .empty(message: "暂无数据") : .content
        case .failure(let error):
            if case .cancelled = error {
                return
            }
            if items.isEmpty {
                listState = .error(message: error.message)
            } else {
                alertMessage = AlertMessage(message: error.message)
            }
        }
    }

    private func showEvent(_ message: String) {
        alertMessage = AlertMessage(message: message)
    }
}
