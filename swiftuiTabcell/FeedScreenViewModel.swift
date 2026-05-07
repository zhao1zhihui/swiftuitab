 import SwiftUI
 import Combine

@MainActor
final class FeedScreenViewModel: ObservableObject, PagingViewModel {
    struct AlertMessage: Identifiable {
        let id = UUID()
        let message: String
    }

    typealias Item = FeedRow

    @Published var items: [FeedRow] = []
    @Published var pagePhase: PagingPhase = .loading
    @Published var alertMessage: AlertMessage?
    @Published var isRefreshing = false
    @Published var isLoadingMore = false

    var paging = PagingState(page: 0, pageSize: 10, hasMore: true)
    private let provider: CardProvider = EnumCardProvider()
    private var initialLoadTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private let minimumLoadMoreIndicatorDuration: TimeInterval = 0.2

    var canLoadMore: Bool {
        paging.hasMore && !items.isEmpty
    }

    func fetch(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedRow>> {
        let result = await provider.loadItems(page: page, pageSize: pageSize)
        return result.map { [self] pageResult in
            pageResult.mapItems(bindCallbacks)
        }
    }

    func refreshContent() async {
        if isLoadingMore || isRefreshing {
            return
        }
        if items.isEmpty {
            pagePhase = .loading
        }
        isRefreshing = true
        defer { isRefreshing = false }

        let result = await refresh()
        guard !Task.isCancelled else { return }
        applyRefresh(result)
    }

    func loadMoreContent() async {
        if isRefreshing || isLoadingMore || !paging.hasMore {
            return
        }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let startedAt = Date()
        let result = await loadMore()
        let elapsed = Date().timeIntervalSince(startedAt)
        if elapsed < minimumLoadMoreIndicatorDuration {
            let remaining = minimumLoadMoreIndicatorDuration - elapsed
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
        guard !Task.isCancelled else { return }
        applyLoadMore(result)
    }

    func startInitialLoadIfNeeded() {
        guard items.isEmpty, initialLoadTask == nil else { return }
        initialLoadTask = Task { @MainActor [weak self] in
            defer { self?.initialLoadTask = nil }
            await self?.refreshContent()
        }
    }

    func triggerLoadMoreIfNeeded() {
        guard canLoadMore else { return }
        guard loadMoreTask == nil else { return }
        loadMoreTask = Task { @MainActor [weak self] in
            defer { self?.loadMoreTask = nil }
            await self?.loadMoreContent()
        }
    }

    func cancelPagingTasks() {
        initialLoadTask?.cancel()
        loadMoreTask?.cancel()
        initialLoadTask = nil
        loadMoreTask = nil
    }

    private func applyRefresh(_ result: APIResult<[FeedRow]>) {
        switch result {
        case .success(let items):
            pagePhase = items.isEmpty ? .empty(message: "暂无数据") : .content
        case .failure(let error):
            if case .cancelled = error {
                return
            }
            if items.isEmpty {
                pagePhase = .error(message: error.message)
            } else {
                alertMessage = AlertMessage(message: error.message)
            }
        }
    }

    private func applyLoadMore(_ result: APIResult<[FeedRow]>) {
        switch result {
        case .success:
            pagePhase = items.isEmpty ? .empty(message: "暂无数据") : .content
        case .failure(let error):
            if case .cancelled = error {
                return
            }
            if items.isEmpty {
                pagePhase = .error(message: error.message)
            } else {
                alertMessage = AlertMessage(message: error.message)
            }
        }
    }

    private func showEvent(_ message: String) {
        alertMessage = AlertMessage(message: message)
    }

    private func bindCallbacks(to row: FeedRow) -> FeedRow {
        switch row {
        case .text(let model):
            return .text(model.binding(onEvent: { [weak self] event, model in
                self?.handleTextEvent(event, model: model)
            }))
        case .image(let model):
            return .image(model.binding(onEvent: { [weak self] event, model in
                self?.handleImageEvent(event, model: model)
            }))
        case .action(let model):
            return .action(model.binding(onEvent: { [weak self] event, model in
                self?.handleActionEvent(event, model: model)
            }))
        case .profile(let model):
            return .profile(model.binding(onEvent: { [weak self] event, model in
                self?.handleProfileEvent(event, model: model)
            }))
        }
    }

    private func handleTextEvent(_ event: TextRowModel.Event, model: TextRowModel) {
        switch event {
        case .tapTitle:
            showEvent("Text 事件: 点击了 title, id = \(model.id), title = \(model.title)")
        case .tapSubtitle:
            showEvent("Text 事件: 点击了 subtitle, id = \(model.id), title = \(model.title)")
        }
    }

    private func handleImageEvent(_ event: ImageRowModel.Event, model: ImageRowModel) {
        switch event {
        case .tapTitle:
            showEvent("Image 事件: 点击了 title, id = \(model.id), title = \(model.title)")
        case .tapImage:
            showEvent("Image 事件: 点击了 image, id = \(model.id), title = \(model.title)")
        case .tapURL:
            showEvent("Image 事件: 点击了 url, id = \(model.id), title = \(model.title)")
        }
    }

    private func handleActionEvent(_ event: ActionRowModel.Event, model: ActionRowModel) {
        switch event {
        case .tapTitle:
            showEvent("Action 事件: 点击了 title, id = \(model.id), title = \(model.title)")
        case .tapButton:
            showEvent("Action 事件: 点击了 button, id = \(model.id), title = \(model.title)")
        }
    }

    private func handleProfileEvent(_ event: ProfileRowModel.Event, model: ProfileRowModel) {
        switch event {
        case .tapName:
            showEvent("Profile 事件: 点击了 name, id = \(model.id), name = \(model.name)")
        case .tapFollow:
            showEvent("Profile 事件: 点击了 follow, id = \(model.id), name = \(model.name)")
        case .tapMessage:
            showEvent("Profile 事件: 点击了 message, id = \(model.id), name = \(model.name)")
        }
    }
}
