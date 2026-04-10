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
    let loadMorePreloadDistance: CGFloat
    let enableCardScrollEffect: Bool
    let cardScrollEffectDistance: CGFloat
    let cardScrollMinScale: CGFloat
    let cardScrollMinOpacity: CGFloat
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
        loadMorePreloadDistance: 80,
        enableCardScrollEffect: true,
        cardScrollEffectDistance: 140,
        cardScrollMinScale: 0.72,
        cardScrollMinOpacity: 1.0,
        loadingText: "加载中...",
        emptyButtonTitle: "重新加载",
        retryButtonTitle: "重试",
        stateViewStyle: .default
    )
}

// 在指定坐标空间里上报内容底部（maxY）位置。
private struct ScrollContentMaxYPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = .greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollViewportHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct RowMinYPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct RowHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollReactiveCardModifier: ViewModifier {
    let coordinateSpaceName: String
    let effectDistance: CGFloat
    let minScale: CGFloat
    let minOpacity: CGFloat

    @State private var rowMinY: CGFloat = 0
    @State private var rowHeight: CGFloat = 0

    func body(content: Content) -> some View {
        // 规则：卡片向上滑动到“有一半被顶部遮住”后，才开始缩放/淡出。
        // startMinY = -rowHeight * 0.5
        let startMinY = -rowHeight * 0.5
        let progress = min(max((startMinY - rowMinY) / max(effectDistance, 1), 0), 1)
        let scale = 1 - (1 - minScale) * progress
        let opacity = 1 - (1 - minOpacity) * progress

        return content
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: progress * 6)
            .animation(.easeOut(duration: 0.18), value: progress)
            .overlay(
                GeometryReader { proxy in
                    // 在统一命名坐标空间里读取当前卡片的 minY。
                    Color.clear.preference(
                        key: RowMinYPreferenceKey.self,
                        value: proxy.frame(in: .named(coordinateSpaceName)).minY
                    )
                    .preference(
                        key: RowHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            )
            .onPreferenceChange(RowMinYPreferenceKey.self) { value in
                rowMinY = value
            }
            .onPreferenceChange(RowHeightPreferenceKey.self) { value in
                rowHeight = value
            }
    }
}

private struct ScrollLoadMoreModifier: ViewModifier {
    let coordinateSpaceName: String
    let preloadDistance: CGFloat
    let canTrigger: Bool
    let triggerToken: Int
    let onTrigger: () -> Void

    @State private var lastTriggeredToken: Int = -1
    @State private var viewportHeight: CGFloat = 0
    @State private var contentMaxY: CGFloat = .greatestFiniteMagnitude

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    // 这里同时上报两类度量值：
                    // 1) 可视区域高度（viewportHeight）
                    // 2) 内容底部在命名坐标空间中的 maxY（contentMaxY）
                    // 后面会用它们计算“接近底部”的触发阈值。
                    Color.clear
                        .preference(
                            key: ScrollViewportHeightPreferenceKey.self,
                            value: proxy.size.height
                        )
                        .preference(
                            key: ScrollContentMaxYPreferenceKey.self,
                            value: proxy.frame(in: .named(coordinateSpaceName)).maxY
                        )
                }
            )
            .onPreferenceChange(ScrollViewportHeightPreferenceKey.self) { height in
                viewportHeight = height
                evaluate()
            }
            .onPreferenceChange(ScrollContentMaxYPreferenceKey.self) { contentMaxY in
                self.contentMaxY = contentMaxY
                evaluate()
            }
            .onChange(of: canTrigger) { _, canTrigger in
                if !canTrigger {
                    lastTriggeredToken = -1
                }
            }
    }

    private func evaluate() {
        guard canTrigger, viewportHeight > 0 else { return }

        // 当内容底部进入「可视高度 + 预加载距离」时触发加载更多。
        let threshold = viewportHeight + preloadDistance
        guard contentMaxY <= threshold else {
            // 只有滚离底部后才重置，避免同一页重复触发。
            if lastTriggeredToken == triggerToken {
                lastTriggeredToken = -1
            }
            return
        }

        // triggerToken 通常是 items.count：同一批数据只触发一次。
        guard lastTriggeredToken != triggerToken else { return }
        lastTriggeredToken = triggerToken
        onTrigger()
    }
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

    func onScrollNearBottom(coordinateSpaceName: String,
                            preloadDistance: CGFloat,
                            canTrigger: Bool,
                            triggerToken: Int,
                            perform action: @escaping () -> Void) -> some View {
        // coordinateSpaceName 表示“统一的坐标参照系名称”。
        // ScrollView 和内容都使用同一个名称，才能得到可比较的位置值。
        modifier(
            ScrollLoadMoreModifier(
                coordinateSpaceName: coordinateSpaceName,
                preloadDistance: preloadDistance,
                canTrigger: canTrigger,
                triggerToken: triggerToken,
                onTrigger: action
            )
        )
    }

    func scrollReactiveCardEffect(coordinateSpaceName: String,
                                  distance: CGFloat,
                                  minScale: CGFloat,
                                  minOpacity: CGFloat) -> some View {
        modifier(
            ScrollReactiveCardModifier(
                coordinateSpaceName: coordinateSpaceName,
                effectDistance: distance,
                minScale: minScale,
                minOpacity: minOpacity
            )
        )
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
            rowsContainer
            .padding(.horizontal, resolvedHorizontalPadding)
            .padding(.bottom, style.bottomPadding)
            .onScrollNearBottom(
                coordinateSpaceName: "paging-scroll-space",
                preloadDistance: style.loadMorePreloadDistance,
                canTrigger: canLoadMore && !isLoadingMore,
                triggerToken: items.count,
                perform: onLoadMoreTrigger
            )
        }
        .coordinateSpace(name: "paging-scroll-space")
        .refreshable {
            await onRefresh()
        }
    }

    @ViewBuilder
    private var rowsContainer: some View {
        if style.enableCardScrollEffect {
            // 开启滚动动画时，使用 VStack 避免 Lazy 回收导致的动画中断。
            VStack(spacing: style.itemSpacing) {
                ForEach(items) { item in
                    cardRow(for: item)
                }
                loadMoreFooter
            }
        } else {
            LazyVStack(spacing: style.itemSpacing) {
                ForEach(items) { item in
                    cardRow(for: item)
                }
                loadMoreFooter
            }
        }
    }

    @ViewBuilder
    private func cardRow(for item: Item) -> some View {
        if style.enableCardScrollEffect {
            rowContent(item)
                .scrollReactiveCardEffect(
                    coordinateSpaceName: "paging-scroll-space",
                    distance: style.cardScrollEffectDistance,
                    minScale: style.cardScrollMinScale,
                    minOpacity: style.cardScrollMinOpacity
                )
        } else {
            rowContent(item)
        }
    }

    @ViewBuilder
    private var loadMoreFooter: some View {
        if isLoadingMore {
            ProgressView()
                .padding(.vertical, style.loadingMorePadding)
        } else if canLoadMore {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: style.loadMoreTriggerHeight)
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
