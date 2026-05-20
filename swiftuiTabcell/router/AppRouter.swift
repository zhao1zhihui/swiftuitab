import Foundation
import Combine

struct BackNavigationAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

private struct PendingBackConfirmation {
    let tab: AppTab
    let path: [AppRoute]
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .feed
    @Published var feedPath: [AppRoute] = []
    @Published var discoverPath: [AppRoute] = []
    @Published var accountPath: [AppRoute] = []
    @Published var backAlert: BackNavigationAlert?

    private let session: AppSession
    private let observability: AppObservability
    private var pendingProtectedRoute: AppRoute?
    private var pendingBackConfirmation: PendingBackConfirmation?

    init(session: AppSession,
         observability: AppObservability = .makeConsole()) {
        self.session = session
        self.observability = observability
    }

    func push(_ route: AppRoute) {
        Task {
            await navigate(to: route)
        }
    }

    func navigate(to route: AppRoute) async {
        clearBackConfirmation()

        if route.requiresAuth && !session.isLoggedIn {
            pendingProtectedRoute = route
            append(.login, on: .account)
            return
        }

        if pendingProtectedRoute == route {
            pendingProtectedRoute = nil
        }
        append(route, on: route.preferredTab)
    }

    /// SwiftUI NavigationStack 的系统返回会表现为 path 变短。
    /// 这里集中判断是否允许系统返回，避免每个页面自己写侧滑/返回拦截。
    func applyNavigationPath(_ newPath: [AppRoute], on tab: AppTab) {
        let oldPath = path(on: tab)

        if let blockedRoute = blockedRouteWhenPopping(from: oldPath, to: newPath) {
            showBackConfirmation(for: blockedRoute, on: tab, nextPath: newPath, source: "path")
            return
        }

        setPath(newPath, on: tab)
    }

    /// 侧滑返回在 UIKit 手势 shouldBegin 阶段进入这里。
    /// 返回 false 会阻止本次侧滑动画，同时弹出确认框；确认框里再执行真正的 pop。
    func shouldBeginInteractiveBack(from route: AppRoute, on tab: AppTab) -> Bool {
        let oldPath = path(on: tab)
        guard oldPath.last == route else {
            return true
        }

        guard !route.backPolicy.allowsSystemBack else {
            return true
        }

        showBackConfirmation(for: route, on: tab, nextPath: Array(oldPath.dropLast()), source: "gesture")
        return false
    }

    /// 页面内“关闭/完成”按钮属于业务行为，默认绕过系统返回拦截。
    /// 如果某个业务动作也要二次确认，应在对应 ViewModel 或 UseCase 里做确认。
    func pop(on tab: AppTab? = nil) {
        clearBackConfirmation()

        let targetTab = tab ?? selectedTab
        switch targetTab {
        case .feed:
            guard !feedPath.isEmpty else { return }
            feedPath.removeLast()
        case .discover:
            guard !discoverPath.isEmpty else { return }
            discoverPath.removeLast()
        case .account:
            guard !accountPath.isEmpty else { return }
            accountPath.removeLast()
        }
    }

    func popToRoot(on tab: AppTab? = nil) {
        clearBackConfirmation()

        let targetTab = tab ?? selectedTab
        switch targetTab {
        case .feed:
            feedPath.removeAll()
        case .discover:
            discoverPath.removeAll()
        case .account:
            accountPath.removeAll()
        }
    }

    func handleLoginSuccess() async {
        clearBackConfirmation()

        if accountPath.last == .login {
            accountPath.removeLast()
        }

        guard let pendingProtectedRoute else {
            selectedTab = .account
            return
        }

        self.pendingProtectedRoute = nil
        await navigate(to: pendingProtectedRoute)
    }

    func clearProtectedContinuation() {
        pendingProtectedRoute = nil
    }

    /// 用户在确认弹窗里点“继续返回”时，执行这次被拦下的 pop。
    func confirmBlockedBack() {
        guard let pendingBackConfirmation else { return }
        self.pendingBackConfirmation = nil
        backAlert = nil
        setPath(pendingBackConfirmation.path, on: pendingBackConfirmation.tab)
    }

    /// 用户取消返回确认后，只清理临时状态，不改导航栈。
    func cancelBlockedBack() {
        pendingBackConfirmation = nil
        backAlert = nil
    }

    func handleURL(_ url: URL) async {
        clearBackConfirmation()

        guard let intent = AppRouteParser.parse(url) else {
            observability.errorReporter.report(
                AppReportedError(
                    source: "router.deep_link",
                    message: "无法解析 URL",
                    metadata: ["url": url.absoluteString]
                )
            )
            return
        }

        switch intent {
        case .tab(let tab):
            selectedTab = tab
        case .route(let route):
            await navigate(to: route)
        case .notFound(let path, let originalURL):
            observability.errorReporter.report(
                AppReportedError(
                    source: "router.deep_link.not_found",
                    message: "没有找到可处理的深链路由",
                    metadata: [
                        "path": path,
                        "url": originalURL
                    ]
                )
            )
            append(.routeNotFound(path: path), on: .discover)
        }
    }

    private func append(_ route: AppRoute, on tab: AppTab) {
        selectedTab = tab

        switch tab {
        case .feed:
            feedPath.append(route)
        case .discover:
            if discoverPath.last != route {
                discoverPath.append(route)
            }
        case .account:
            if route == .login, accountPath.last == .login {
                return
            }
            accountPath.append(route)
        }
    }

    private func path(on tab: AppTab) -> [AppRoute] {
        switch tab {
        case .feed:
            return feedPath
        case .discover:
            return discoverPath
        case .account:
            return accountPath
        }
    }

    private func setPath(_ path: [AppRoute], on tab: AppTab) {
        switch tab {
        case .feed:
            feedPath = path
        case .discover:
            discoverPath = path
        case .account:
            accountPath = path
        }
    }

    private func showBackConfirmation(for route: AppRoute,
                                      on tab: AppTab,
                                      nextPath: [AppRoute],
                                      source: String) {
        guard pendingBackConfirmation == nil else {
            return
        }

        pendingBackConfirmation = PendingBackConfirmation(tab: tab, path: nextPath)
        let policy = route.backPolicy
        backAlert = BackNavigationAlert(
            title: policy.blockedTitle,
            message: policy.blockedMessage
        )
        observability.track(
            "navigation.back_blocked",
            metadata: [
                "route": route.id,
                "tab": tab.rawValue,
                "source": source
            ]
        )
    }

    private func clearBackConfirmation() {
        pendingBackConfirmation = nil
        backAlert = nil
    }

    private func blockedRouteWhenPopping(from oldPath: [AppRoute], to newPath: [AppRoute]) -> AppRoute? {
        guard newPath.count < oldPath.count else {
            return nil
        }

        let removedRoutes = oldPath.dropFirst(newPath.count)
        return removedRoutes.reversed().first { route in
            !route.backPolicy.allowsSystemBack
        }
    }
}
