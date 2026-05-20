import Foundation
import Combine

@MainActor
final class FeedScreenViewModel: ObservableObject, PagingViewModel {
    struct AlertMessage: Identifiable {
        let presentation: AppErrorPresentation

        var id: String {
            presentation.id
        }

        var title: String {
            presentation.title
        }

        var message: String {
            presentation.message
        }
    }

    typealias Item = FeedRow

    @Published var items: [FeedRow] = []
    @Published var pagePhase: PagingPhase = .loading
    @Published var alertMessage: AlertMessage?
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published private(set) var loadMoreResetToken = 0

    var paging = PagingState(page: 0, pageSize: 10, hasMore: true)
    private let provider: CardProvider
    private let observability: AppObservability
    private let errorPresenter: any AppErrorPresenting
    private let clock: any AppClock
    private let minimumLoadMoreIndicatorDuration: TimeInterval = 0.2

    /// ViewModel 只依赖 Provider 协议，测试时可以直接注入假数据源。
    init(provider: CardProvider,
         observability: AppObservability = .makeConsole(),
         errorPresenter: any AppErrorPresenting = DefaultAppErrorPresenter(),
         clock: any AppClock = SystemAppClock()) {
        self.provider = provider
        self.observability = observability
        self.errorPresenter = errorPresenter
        self.clock = clock
    }

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
        loadMoreResetToken &+= 1
        applyRefresh(result)
    }

    func loadMoreContent() async {
        if isRefreshing || isLoadingMore || !paging.hasMore {
            return
        }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let startedAt = clock.now
        let result = await loadMore()
        let elapsed = clock.now.timeIntervalSince(startedAt)
        if elapsed < minimumLoadMoreIndicatorDuration {
            let remaining = minimumLoadMoreIndicatorDuration - elapsed
            try? await clock.sleep(for: remaining)
        }
        guard !Task.isCancelled else { return }
        applyLoadMore(result)
    }

    func refreshContentIfNeeded() async {
        guard items.isEmpty else { return }
        await refreshContent()
    }

    func loadMoreIfNeeded() async {
        guard canLoadMore else { return }
        await loadMoreContent()
    }

    private func applyRefresh(_ result: APIResult<[FeedRow]>) {
        switch result {
        case .success(let items):
            pagePhase = items.isEmpty ? .empty(message: "暂无数据") : .content
        case .failure(let error):
            if case .cancelled = error {
                return
            }
            observability.report(error, source: "feed.refresh")
            if items.isEmpty {
                let presentation = makeErrorPresentation(for: error, id: "feed.refresh")
                pagePhase = .error(message: presentation.message)
            } else {
                alertMessage = AlertMessage(presentation: makeErrorPresentation(for: error, id: "feed.refresh.toast"))
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
            observability.report(error, source: "feed.load_more")
            if items.isEmpty {
                let presentation = makeErrorPresentation(for: error, id: "feed.load_more")
                pagePhase = .error(message: presentation.message)
            } else {
                alertMessage = AlertMessage(presentation: makeErrorPresentation(for: error, id: "feed.load_more.toast"))
            }
        }
    }

    private func makeErrorPresentation(for error: APIError, id: String) -> AppErrorPresentation {
        errorPresenter.presentation(for: error, id: id)
    }

    private func showEvent(_ message: String) {
        alertMessage = AlertMessage(
            presentation: AppErrorPresentation(
                id: "feed.event.\(message.hashValue)",
                title: "提示",
                message: message,
                actionTitle: "知道了",
                severity: .info,
                isRetryable: false
            )
        )
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
