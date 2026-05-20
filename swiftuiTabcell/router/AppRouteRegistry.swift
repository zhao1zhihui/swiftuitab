import Foundation

/// 路由注册表。
/// 这里是“业务入口白名单”，后续新增页面、深链、默认 tab 和返回策略都应该先在这里登记。
nonisolated struct AppRouteRegistryEntry: Sendable {
    let route: AppRoute
    let preferredTab: AppTab
    let requiresAuth: Bool
    let backPolicy: BackNavigationPolicy

    init(route: AppRoute,
         preferredTab: AppTab? = nil,
         requiresAuth: Bool? = nil,
         backPolicy: BackNavigationPolicy? = nil) {
        self.route = route
        self.preferredTab = preferredTab ?? route.preferredTab
        self.requiresAuth = requiresAuth ?? route.requiresAuth
        self.backPolicy = backPolicy ?? route.backPolicy
    }
}

nonisolated struct AppRouteRegistry {
    static let shared = AppRouteRegistry()

    private let entries: [AppRouteEntryKey: AppRouteRegistryEntry]

    init(entries: [AppRouteEntryKey: AppRouteRegistryEntry] = AppRouteRegistry.defaultEntries) {
        self.entries = entries
    }

    func entry(for route: AppRoute) -> AppRouteRegistryEntry? {
        entries[AppRouteEntryKey(route: route)]
    }

    func validate(_ route: AppRoute) -> Bool {
        entry(for: route) != nil
    }

    private static var defaultEntries: [AppRouteEntryKey: AppRouteRegistryEntry] {
        let routes: [AppRoute] = [
            .settings,
            .orders,
            .login,
            .routeNotFound(path: "/sample"),
            .basic(params: BasicPageParams()),
            .gestureConflictDemo(mode: .directAtLeadingEdge),
            .gestureConflictDemo(mode: .secondSwipeAtLeadingEdge),
            .productDetail(params: ProductDetailParams(productId: "sample")),
            .orderDetail(params: OrderDetailParams(orderId: "sample")),
            .profile(params: ProfileParams(userId: "sample"))
        ]

        var dictionary: [AppRouteEntryKey: AppRouteRegistryEntry] = [:]
        routes.forEach { route in
            dictionary[AppRouteEntryKey(route: route)] = AppRouteRegistryEntry(route: route)
        }
        return dictionary
    }
}

nonisolated struct AppRouteEntryKey: Hashable, Sendable {
    private let identifier: String

    init(route: AppRoute) {
        switch route {
        case .settings:
            self.identifier = "settings"
        case .orders:
            self.identifier = "orders"
        case .login:
            self.identifier = "login"
        case .routeNotFound:
            self.identifier = "route-not-found"
        case .basic:
            self.identifier = "basic"
        case .gestureConflictDemo(let mode):
            self.identifier = "gesture-conflict-demo.\(mode.rawValue)"
        case .productDetail:
            self.identifier = "product-detail"
        case .orderDetail:
            self.identifier = "order-detail"
        case .profile:
            self.identifier = "profile"
        }
    }
}
