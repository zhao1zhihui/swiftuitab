import Foundation
import Combine

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .feed
    @Published var feedPath: [AppRoute] = []
    @Published var discoverPath: [AppRoute] = []
    @Published var accountPath: [AppRoute] = []

    private let session: AppSession
    private var pendingProtectedRoute: AppRoute?

    init(session: AppSession) {
        self.session = session
    }

    func push(_ route: AppRoute) {
        Task {
            await navigate(to: route)
        }
    }

    func navigate(to route: AppRoute) async {
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

    func pop(on tab: AppTab? = nil) {
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

    func handleURL(_ url: URL) async {
        guard let intent = AppRouteParser.parse(url) else {
            print("❌ 无法解析 URL: \(url.absoluteString)")
            return
        }

        switch intent {
        case .tab(let tab):
            selectedTab = tab
        case .route(let route):
            await navigate(to: route)
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
}
