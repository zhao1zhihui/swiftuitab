internal import SwiftUI
internal import Combine

@MainActor
final class FeedScreenViewModel: ObservableObject, PagingViewModel {
    enum ProviderMode: String, CaseIterable, Identifiable {
        case enumMapping = "Enum"
        case registry = "Registry"

        var id: String { rawValue }
    }

    enum ListState: Equatable {
        case content
        case empty(message: String)
        case error(message: String)
    }

    struct AlertMessage: Identifiable {
        let id = UUID()
        let message: String
    }

    typealias Item = AnyCardItem

    @Published var items: [AnyCardItem] = []
    @Published var listState: ListState = .content
    @Published var alertMessage: AlertMessage?
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var hasLoadedOnce = false
    @Published var providerMode: ProviderMode = .enumMapping

    var paging = PagingState(page: 0, pageSize: 10, hasMore: true)

    private lazy var textCallbacks: TextCardCallbacks = {
        var callbacks = TextCardCallbacks()
        callbacks.onTitleTap = { [weak self] id in
            self?.showEvent("闭包事件: 点击了 Text title, id = \(id)")
        }
        callbacks.onSubtitleTap = { [weak self] id in
            self?.showEvent("闭包事件: 点击了 Text subtitle, id = \(id)")
        }
        return callbacks
    }()

    private lazy var imageEventHandler: ImageCardEventHandler = {
        var handler = ImageCardEventHandler()
        handler.onEvent = { [weak self] id, event in
            switch event {
            case .tapTitle:
                self?.showEvent("enum 事件: 点击了 Image title, id = \(id)")
            case .tapImage:
                self?.showEvent("enum 事件: 点击了 Image image, id = \(id)")
            case .tapURL:
                self?.showEvent("enum 事件: 点击了 Image url, id = \(id)")
            }
        }
        return handler
    }()

    func fetch(page: Int, pageSize: Int) async -> APIResult<PageResult<AnyCardItem>> {
        await makeProvider().loadItems(page: page, pageSize: pageSize)
    }

    func refreshContent() async {
        if isLoadingMore || isRefreshing {
            return
        }
        isRefreshing = true
        let requestedMode = providerMode
        defer { isRefreshing = false }

        let result = await refresh()
        guard !Task.isCancelled, requestedMode == providerMode else { return }
        applyRefresh(result)
        hasLoadedOnce = true
    }

    func loadMoreContent() async {
        if isRefreshing || isLoadingMore || !paging.hasMore {
            return
        }
        isLoadingMore = true
        let requestedMode = providerMode
        defer { isLoadingMore = false }

        let result = await loadMore()
        guard !Task.isCancelled, requestedMode == providerMode else { return }
        applyLoadMore(result)
    }

    func loadMoreIfNeeded(currentItemID: String) async {
        guard currentItemID == items.last?.id else { return }
        await loadMoreContent()
    }

    func changeMode(to mode: ProviderMode) async {
        guard mode != providerMode else { return }
        providerMode = mode
        items = []
        hasLoadedOnce = false
        paging = PagingState(page: 0, pageSize: paging.pageSize, hasMore: true)
        listState = .content
        await refreshContent()
    }

    private func makeProvider() -> CardProvider {
        switch providerMode {
        case .enumMapping:
            return EnumCardProvider(
                textCallbacks: textCallbacks,
                imageEventHandler: imageEventHandler,
                actionDelegate: self,
                profileDelegate: self
            )
        case .registry:
            return RegistryCardProvider(
                textCallbacks: textCallbacks,
                imageEventHandler: imageEventHandler,
                actionDelegate: self,
                profileDelegate: self
            )
        }
    }

    private func applyRefresh(_ result: APIResult<[AnyCardItem]>) {
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

    private func applyLoadMore(_ result: APIResult<[AnyCardItem]>) {
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

extension FeedScreenViewModel: ActionCardEventDelegate {
    func actionCardDidTapTitle(id: Int) {
        showEvent("delegate 事件: 点击了 Action title, id = \(id)")
    }

    func actionCardDidTapButton(id: Int) {
        showEvent("delegate 事件: 点击了 Action button, id = \(id)")
    }
}

extension FeedScreenViewModel: ProfileCardEventDelegate {
    func profileCardDidTapName(id: Int) {
        showEvent("delegate 事件: 点击了 Profile name, id = \(id)")
    }

    func profileCardDidTapFollow(id: Int) {
        showEvent("delegate 事件: 点击了 Profile follow, id = \(id)")
    }

    func profileCardDidTapMessage(id: Int) {
        showEvent("delegate 事件: 点击了 Profile message, id = \(id)")
    }
}
