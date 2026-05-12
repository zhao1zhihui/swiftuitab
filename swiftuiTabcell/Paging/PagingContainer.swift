import SwiftUI
import UIKit

enum PagingPhase: Equatable {
    case loading
    case content
    case empty(message: String)
    case error(message: String)
}

struct PagingContainerStyle {
    let itemSpacing: CGFloat
    let horizontalPadding: CGFloat
    let bottomPadding: CGFloat
    let loadingMorePadding: CGFloat
    let loadMoreTriggerHeight: CGFloat
    let loadMorePreloadDistance: CGFloat
    let loadingText: String
    let emptyButtonTitle: String
    let retryButtonTitle: String
    let stateViewStyle: FeedStateViewStyle

    static let feedDefault = PagingContainerStyle(
        itemSpacing: 12,
        horizontalPadding: 16,
        bottomPadding: 16,
        loadingMorePadding: 16,
        loadMoreTriggerHeight: 24,
        loadMorePreloadDistance: 120,
        loadingText: "加载中...",
        emptyButtonTitle: "重新加载",
        retryButtonTitle: "重试",
        stateViewStyle: .default
    )
}

private struct PagingContainerPaddingKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

private struct PagingStateViewStyleKey: EnvironmentKey {
    static let defaultValue: FeedStateViewStyle? = nil
}

extension EnvironmentValues {
    var pagingContainerPadding: CGFloat? {
        get { self[PagingContainerPaddingKey.self] }
        set { self[PagingContainerPaddingKey.self] = newValue }
    }

    var pagingStateViewStyle: FeedStateViewStyle? {
        get { self[PagingStateViewStyleKey.self] }
        set { self[PagingStateViewStyleKey.self] = newValue }
    }
}

extension View {
    func pagingContainerPadding(_ value: CGFloat) -> some View {
        environment(\.pagingContainerPadding, value)
    }

    func pagingStateViewStyle(_ style: FeedStateViewStyle) -> some View {
        environment(\.pagingStateViewStyle, style)
    }
}

struct PagingContainer<Item: Identifiable, RowContent: View>: View {
    @State private var lastLoadMoreTriggerKey = ""
    @State private var refreshRequestID = 0
    @State private var refreshCompletionID = 0
    @State private var retryRequestID = 0
    @State private var loadMoreRequestID = 0

    @Environment(\.pagingContainerPadding) private var paddingOverride
    @Environment(\.pagingStateViewStyle) private var stateViewStyleOverride

    let items: [Item]
    let phase: PagingPhase
    let canLoadMore: Bool
    let isRefreshing: Bool
    let isLoadingMore: Bool
    let loadMoreResetToken: Int
    let style: PagingContainerStyle
    let onRefresh: () async -> Void
    let onRetry: () async -> Void
    let onLoadMore: () async -> Void
    let rowContent: (Item) -> RowContent

    var body: some View {
        Group {
            if items.isEmpty {
                stateView
            } else {
                contentView
            }
        }
        .task(id: loadMoreResetToken) {
            lastLoadMoreTriggerKey = ""
        }
        .task(id: items.count) {
            if !canLoadMore {
                lastLoadMoreTriggerKey = ""
            }
        }
        .task(id: retryRequestID) {
            guard retryRequestID > 0 else { return }
            await onRetry()
        }
        .task(id: refreshRequestID) {
            guard refreshRequestID > 0 else { return }
            await onRefresh()
            refreshCompletionID &+= 1
        }
        .task(id: loadMoreRequestID) {
            guard loadMoreRequestID > 0 else { return }
            await onLoadMore()
        }
    }

    private var resolvedHorizontalPadding: CGFloat {
        paddingOverride ?? style.horizontalPadding
    }

    private var resolvedStateViewStyle: FeedStateViewStyle {
        stateViewStyleOverride ?? style.stateViewStyle
    }

    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: style.itemSpacing) {
                ForEach(items) { item in
                    rowContent(item)
                }

                loadMoreFooter
            }
            .padding(.horizontal, resolvedHorizontalPadding)
            .padding(.bottom, style.bottomPadding)
        }
        .background(scrollObserver)
    }

    private var scrollObserver: some View {
        PagingScrollViewObserver(
            itemsCount: items.count,
            resetToken: loadMoreResetToken,
            refreshCompletionID: refreshCompletionID,
            preloadDistance: style.loadMorePreloadDistance,
            canLoadMore: canLoadMore,
            isRefreshing: isRefreshing,
            isLoadingMore: isLoadingMore,
            onTrigger: {
                let triggerKey = "\(loadMoreResetToken)-\(items.count)"
                guard lastLoadMoreTriggerKey != triggerKey else { return }
                lastLoadMoreTriggerKey = triggerKey
                loadMoreRequestID &+= 1
            },
            onRefreshRequested: {
                refreshRequestID &+= 1
            }
        )
        .frame(width: 0, height: 0)
    }

    @ViewBuilder
    private var loadMoreFooter: some View {
        if canLoadMore {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: style.loadMoreTriggerHeight)
        }
        if isLoadingMore {
            ProgressView()
                .padding(.vertical, style.loadingMorePadding)
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch phase {
        case .loading:
            ProgressView(style.loadingText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .content:
            EmptyView()
        case .empty(let message):
            FeedStateView(
                title: message,
                buttonTitle: style.emptyButtonTitle,
                style: resolvedStateViewStyle,
                action: {
                    retryRequestID &+= 1
                }
            )
        case .error(let message):
            FeedStateView(
                title: message,
                buttonTitle: style.retryButtonTitle,
                style: resolvedStateViewStyle,
                action: {
                    retryRequestID &+= 1
                }
            )
        }
    }
}

private struct PagingScrollViewObserver: UIViewRepresentable {
    let itemsCount: Int
    let resetToken: Int
    let refreshCompletionID: Int
    let preloadDistance: CGFloat
    let canLoadMore: Bool
    let isRefreshing: Bool
    let isLoadingMore: Bool
    let onTrigger: () -> Void
    let onRefreshRequested: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTrigger: onTrigger)
    }

    func makeUIView(context: Context) -> PagingScrollObserverView {
        let view = PagingScrollObserverView()
        view.onScrollMetricsChange = { scrollView in
            context.coordinator.evaluate(scrollView)
        }
        view.onRefreshRequested = {
            onRefreshRequested()
        }
        return view
    }

    func updateUIView(_ view: PagingScrollObserverView, context: Context) {
        context.coordinator.update(
            itemsCount: itemsCount,
            resetToken: resetToken,
            preloadDistance: preloadDistance,
            canLoadMore: canLoadMore,
            isRefreshing: isRefreshing,
            isLoadingMore: isLoadingMore,
            onTrigger: onTrigger
        )
        view.onRefreshRequested = {
            onRefreshRequested()
        }
        view.bindToNearestScrollViewIfNeeded()
        view.updateRefreshControl(isRefreshing: isRefreshing, completionID: refreshCompletionID)
    }

    @MainActor
    final class Coordinator {
        private var itemsCount = 0
        private var resetToken = 0
        private var preloadDistance: CGFloat = 0
        private var canLoadMore = false
        private var isRefreshing = false
        private var isLoadingMore = false
        private var lastTriggerKey = ""
        private var onTrigger: () -> Void

        init(onTrigger: @escaping () -> Void) {
            self.onTrigger = onTrigger
        }

        func update(itemsCount: Int,
                    resetToken: Int,
                    preloadDistance: CGFloat,
                    canLoadMore: Bool,
                    isRefreshing: Bool,
                    isLoadingMore: Bool,
                    onTrigger: @escaping () -> Void) {
            if self.resetToken != resetToken || self.itemsCount != itemsCount {
                lastTriggerKey = ""
            }

            self.itemsCount = itemsCount
            self.resetToken = resetToken
            self.preloadDistance = preloadDistance
            self.canLoadMore = canLoadMore
            self.isRefreshing = isRefreshing
            self.isLoadingMore = isLoadingMore
            self.onTrigger = onTrigger
        }

        func evaluate(_ scrollView: UIScrollView) {
            guard canLoadMore, !isRefreshing, !isLoadingMore else { return }
            guard scrollView.bounds.height > 0, scrollView.contentSize.height > 0 else { return }
            guard scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating else { return }
            guard scrollView.contentOffset.y > 0 else { return }

            let visibleBottom = scrollView.contentOffset.y + scrollView.bounds.height - scrollView.adjustedContentInset.bottom
            let distanceToBottom = scrollView.contentSize.height - visibleBottom
            guard distanceToBottom <= preloadDistance else { return }

            let triggerKey = "\(resetToken)-\(itemsCount)"
            guard lastTriggerKey != triggerKey else { return }
            lastTriggerKey = triggerKey
            onTrigger()
        }
    }
}

@MainActor
private final class PagingScrollObserverView: UIView {
    weak var scrollView: UIScrollView?
    var onScrollMetricsChange: ((UIScrollView) -> Void)?
    var onRefreshRequested: (() -> Void)?

    private var offsetObservation: NSKeyValueObservation?
    private var sizeObservation: NSKeyValueObservation?
    private var boundsObservation: NSKeyValueObservation?
    private var lastRefreshCompletionID = 0
    private var latestIsRefreshing = false
    private var latestRefreshCompletionID = 0
    private var isRefreshRequestInFlight = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        bindToNearestScrollViewIfNeeded()
    }

    func bindToNearestScrollViewIfNeeded() {
        guard scrollView == nil else { return }

        var current: UIView? = superview
        while let view = current {
            if let scrollView = view as? UIScrollView {
                bind(to: scrollView)
                return
            }
            current = view.superview
        }

        DispatchQueue.main.async { [weak self] in
            self?.bindToNearestScrollViewIfNeeded()
        }
    }

    private func bind(to scrollView: UIScrollView) {
        self.scrollView = scrollView
        installRefreshControlIfNeeded(on: scrollView)

        offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
            Task { @MainActor [weak self] in
                self?.onScrollMetricsChange?(scrollView)
            }
        }
        sizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] scrollView, _ in
            Task { @MainActor [weak self] in
                self?.onScrollMetricsChange?(scrollView)
            }
        }
        boundsObservation = scrollView.observe(\.bounds, options: [.new]) { [weak self] scrollView, _ in
            Task { @MainActor [weak self] in
                self?.onScrollMetricsChange?(scrollView)
            }
        }

        onScrollMetricsChange?(scrollView)
        updateRefreshControl(isRefreshing: latestIsRefreshing, completionID: latestRefreshCompletionID)
    }

    func updateRefreshControl(isRefreshing: Bool, completionID: Int) {
        latestIsRefreshing = isRefreshing
        latestRefreshCompletionID = completionID

        guard let refreshControl = scrollView?.refreshControl else { return }

        if completionID != lastRefreshCompletionID {
            lastRefreshCompletionID = completionID
            endRefreshing(refreshControl)
            return
        }

        if !isRefreshing, refreshControl.isRefreshing {
            endRefreshing(refreshControl)
        }
    }

    private func installRefreshControlIfNeeded(on scrollView: UIScrollView) {
        scrollView.alwaysBounceVertical = true
        guard scrollView.refreshControl == nil else { return }

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshControlValueChanged), for: .valueChanged)
        scrollView.refreshControl = refreshControl
    }

    private func endRefreshing(_ refreshControl: UIRefreshControl) {
        guard refreshControl.isRefreshing || isRefreshRequestInFlight else { return }

        DispatchQueue.main.async { [weak self, weak refreshControl] in
            refreshControl?.endRefreshing()
            self?.isRefreshRequestInFlight = false
        }
    }

    @objc private func refreshControlValueChanged() {
        guard !isRefreshRequestInFlight else { return }
        isRefreshRequestInFlight = true
        onRefreshRequested?()
    }
}
