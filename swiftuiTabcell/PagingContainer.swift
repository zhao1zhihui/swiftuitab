internal import SwiftUI

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
    @Environment(\.pagingContainerPadding) private var paddingOverride
    @Environment(\.pagingStateViewStyle) private var stateViewStyleOverride

    let items: [Item]
    let phase: PagingPhase
    let canLoadMore: Bool
    let isLoadingMore: Bool
    let style: PagingContainerStyle
    let onRefresh: () async -> Void
    let onRetry: () async -> Void
    let onLoadMoreTrigger: () -> Void
    let onDisappear: (() -> Void)?
    let rowContent: (Item) -> RowContent

    var body: some View {
        Group {
            if items.isEmpty {
                stateView
            } else {
                contentView
            }
        }
        .onDisappear {
            onDisappear?()
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
        .refreshable {
            await onRefresh()
        }
    }

    @ViewBuilder
    private var loadMoreFooter: some View {
        if canLoadMore {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: style.loadMoreTriggerHeight)
                .id("paging-load-more-\(items.count)")
                .onAppear {
                    onLoadMoreTrigger()
                }
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
                    Task {
                        await onRetry()
                    }
                }
            )
        case .error(let message):
            FeedStateView(
                title: message,
                buttonTitle: style.retryButtonTitle,
                style: resolvedStateViewStyle,
                action: {
                    Task {
                        await onRetry()
                    }
                }
            )
        }
    }
}
