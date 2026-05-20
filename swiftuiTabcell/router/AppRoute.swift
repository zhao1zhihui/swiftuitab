import Foundation

/// Tab 是纯路由值对象，不持有 UI 状态；显式 nonisolated 避免 Swift 6 默认 MainActor 污染解析逻辑。
nonisolated enum AppTab: String, CaseIterable, Hashable {
    case feed
    case discover
    case account

    var title: String {
        switch self {
        case .feed:
            return "首页"
        case .discover:
            return "发现"
        case .account:
            return "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .feed:
            return "list.bullet.rectangle"
        case .discover:
            return "safari"
        case .account:
            return "person.crop.circle"
        }
    }
}

nonisolated struct BasicPageParams: Hashable {
    enum CloseType: String, Hashable {
        case myself
        case parent
        case root
    }

    let step: Int
    let canGestureBack: Bool
    let closeType: CloseType
    let needLogin: Bool
    let title: String?

    init(step: Int = 1,
         canGestureBack: Bool = true,
         closeType: CloseType = .myself,
         needLogin: Bool = false,
         title: String? = nil) {
        self.step = step
        self.canGestureBack = canGestureBack
        self.closeType = closeType
        self.needLogin = needLogin
        self.title = title
    }

    init(from dict: [String: String]) {
        self.step = Int(dict["step"] ?? "1") ?? 1
        self.canGestureBack = (dict["canGestureBack"] ?? "1") != "0"
        self.closeType = CloseType(rawValue: dict["closeType"] ?? "") ?? .myself
        self.needLogin = (dict["needLogin"] ?? "0") == "1"
        self.title = dict["title"]
    }
}

nonisolated struct ProfileParams: Hashable {
    let userId: String
    let userName: String?

    init(userId: String, userName: String? = nil) {
        self.userId = userId
        self.userName = userName
    }

    init?(from dict: [String: String]) {
        guard let userId = dict["userId"] ?? dict["id"], !userId.isEmpty else {
            return nil
        }
        self.userId = userId
        self.userName = dict["name"]
    }
}

nonisolated struct ProductDetailParams: Hashable {
    let productId: String
    let productName: String?
    let price: Double?

    init(productId: String, productName: String? = nil, price: Double? = nil) {
        self.productId = productId
        self.productName = productName
        self.price = price
    }

    init?(from dict: [String: String]) {
        guard let productId = dict["productId"] ?? dict["id"], !productId.isEmpty else {
            return nil
        }
        self.productId = productId
        self.productName = dict["name"]
        self.price = Double(dict["price"] ?? "")
    }
}

nonisolated struct OrderDetailParams: Hashable {
    let orderId: String
    let status: String?

    init(orderId: String, status: String? = nil) {
        self.orderId = orderId
        self.status = status
    }

    init?(from dict: [String: String]) {
        guard let orderId = dict["orderId"] ?? dict["id"], !orderId.isEmpty else {
            return nil
        }
        self.orderId = orderId
        self.status = dict["status"]
    }
}

nonisolated struct BackNavigationPolicy: Equatable, Sendable {
    /// 是否允许 NavigationStack 自己把 path 缩短。
    /// false 表示系统返回入口需要先弹确认，确认后由 Router 再写入新的 path。
    let allowsSystemBack: Bool

    /// 是否允许 UIKit 交互返回手势进入 shouldBegin。
    /// 这里通常保持 true，让 Router 能在手势开始前弹窗；如果设为 false，手势会被硬禁用。
    let allowsInteractivePop: Bool

    let blockedTitle: String
    let blockedMessage: String

    /// 横向 ScrollView 滑到最左边时，如何把右滑手势交给页面返回。
    /// 这是全屏返回和业务横滑组件最容易冲突的地方，所以必须做成页面策略。
    let horizontalScrollHandoff: HorizontalScrollBackHandoff

    static let allow = BackNavigationPolicy(
        allowsSystemBack: true,
        allowsInteractivePop: true,
        blockedTitle: "",
        blockedMessage: "",
        horizontalScrollHandoff: .directAtLeadingEdge
    )

    /// 返回确认页。
    /// 这类页面不允许系统直接退出，但侧滑手势保持可用，由 Router 统一弹窗确认，用户点确认后再真正 pop。
    static func locked(message: String) -> BackNavigationPolicy {
        BackNavigationPolicy(
            allowsSystemBack: false,
            allowsInteractivePop: true,
            blockedTitle: "当前页面不能直接返回",
            blockedMessage: message,
            horizontalScrollHandoff: .directAtLeadingEdge
        )
    }

    static func allowed(horizontalScrollHandoff: HorizontalScrollBackHandoff) -> BackNavigationPolicy {
        BackNavigationPolicy(
            allowsSystemBack: true,
            allowsInteractivePop: true,
            blockedTitle: "",
            blockedMessage: "",
            horizontalScrollHandoff: horizontalScrollHandoff
        )
    }
}

nonisolated enum HorizontalScrollBackHandoff: String, Hashable, Sendable {
    /// 横向列表已经在最左边时，本次右滑直接交给页面返回。
    case directAtLeadingEdge

    /// 横向列表已经在最左边时，第一次右滑只让列表处理，下一次右滑才交给页面返回。
    case secondSwipeAtLeadingEdge
}

/// AppRoute 只描述“要去哪”，不直接操作 NavigationStack。
/// 这样 URL 解析、鉴权拦截、单元测试都可以脱离 SwiftUI 主线程环境运行。
nonisolated enum AppRoute: Hashable, Identifiable {
    case settings
    case orders
    case login
    case routeNotFound(path: String)
    case basic(params: BasicPageParams)
    case gestureConflictDemo(mode: HorizontalScrollBackHandoff)
    case productDetail(params: ProductDetailParams)
    case orderDetail(params: OrderDetailParams)
    case profile(params: ProfileParams)

    var id: String {
        switch self {
        case .settings:
            return "settings"
        case .orders:
            return "orders"
        case .login:
            return "login"
        case .routeNotFound(let path):
            return "route-not-found-\(path)"
        case .basic(let params):
            return "basic-\(params.step)-\(params.needLogin)-\(params.closeType.rawValue)-\(params.title ?? "")"
        case .gestureConflictDemo(let mode):
            return "gesture-conflict-demo-\(mode.rawValue)"
        case .productDetail(let params):
            return "product-\(params.productId)"
        case .orderDetail(let params):
            return "order-\(params.orderId)"
        case .profile(let params):
            return "profile-\(params.userId)"
        }
    }

    var preferredTab: AppTab {
        switch self {
        case .settings, .orders, .login, .profile:
            return .account
        case .routeNotFound, .basic, .gestureConflictDemo, .productDetail, .orderDetail:
            return .discover
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .orders, .profile:
            return true
        case .basic(let params):
            return params.needLogin
        default:
            return false
        }
    }

    var backPolicy: BackNavigationPolicy {
        switch self {
        case .basic(let params) where !params.canGestureBack:
            return .locked(message: "请使用页面内的关闭按钮完成当前流程。")
        case .gestureConflictDemo(let mode):
            return .allowed(horizontalScrollHandoff: mode)
        default:
            return .allow
        }
    }
}

nonisolated enum AppNavigationIntent {
    case tab(AppTab)
    case route(AppRoute)
    case notFound(path: String, originalURL: String)
}

/// URLParser 是纯字符串解析工具，不能依赖 View 或 Router 状态。
nonisolated struct URLParser {
    static func parse(_ url: URL) -> (path: String, params: [String: String]) {
        var params: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems?.forEach { item in
                params[item.name] = item.value
            }
        }

        if url.scheme == "ftlending", let host = url.host {
            return (path: "/\(host)\(url.path)", params: params)
        }

        return (path: url.path, params: params)
    }

    static func matchPattern(_ pattern: String, path: String) -> [String: String]? {
        let patternComponents = pattern.split(separator: "/")
        let pathComponents = path.split(separator: "/")

        guard patternComponents.count == pathComponents.count else {
            return nil
        }

        var params: [String: String] = [:]
        for (patternComp, pathComp) in zip(patternComponents, pathComponents) {
            if patternComp.hasPrefix(":") {
                params[String(patternComp.dropFirst())] = String(pathComp)
            } else if patternComp != pathComp {
                return nil
            }
        }
        return params
    }
}

/// 深链到业务路由的集中翻译层。
/// Router 只消费解析结果并处理鉴权/入栈，避免每个页面自己解析 URL。
nonisolated enum AppRouteParser {
    static func parse(_ url: URL) -> AppNavigationIntent? {
        let (path, params) = URLParser.parse(url)
        let resolvedIntent: AppNavigationIntent?

        switch path {
        case "/", "/home":
            resolvedIntent = .tab(.feed)
        case "/discover":
            resolvedIntent = .tab(.discover)
        case "/account":
            resolvedIntent = .tab(.account)
        case "/settings":
            resolvedIntent = .route(.settings)
        case "/orders":
            resolvedIntent = .route(.orders)
        case "/login":
            resolvedIntent = .route(.login)
        case "/profile":
            if let profile = ProfileParams(from: params) {
                resolvedIntent = .route(.profile(params: profile))
            } else {
                resolvedIntent = nil
            }
        case "/product":
            if let product = ProductDetailParams(from: params) {
                resolvedIntent = .route(.productDetail(params: product))
            } else {
                resolvedIntent = nil
            }
        case "/product/detail":
            if let product = ProductDetailParams(from: params) {
                resolvedIntent = .route(.productDetail(params: product))
            } else {
                resolvedIntent = nil
            }
        case "/order":
            if let order = OrderDetailParams(from: params) {
                resolvedIntent = .route(.orderDetail(params: order))
            } else {
                resolvedIntent = nil
            }
        case "/order/detail":
            if let order = OrderDetailParams(from: params) {
                resolvedIntent = .route(.orderDetail(params: order))
            } else {
                resolvedIntent = nil
            }
        case "/addition/basic":
            resolvedIntent = .route(.basic(params: BasicPageParams(from: params)))
        default:
            resolvedIntent = parsePatternRoute(path: path, params: params)
        }

        guard let resolvedIntent else {
            return .notFound(path: path, originalURL: AppPrivacyRedactor.redactedURLString(url))
        }

        return validate(resolvedIntent, path: path, originalURL: url)
    }

    private static func parsePatternRoute(path: String, params: [String: String]) -> AppNavigationIntent? {
        if let userId = URLParser.matchPattern("/user/:userId", path: path)?["userId"] {
            var newParams = params
            newParams["userId"] = userId
            guard let profile = ProfileParams(from: newParams) else { return nil }
            return .route(.profile(params: profile))
        }

        if let productId = URLParser.matchPattern("/product/:productId", path: path)?["productId"] {
            var newParams = params
            newParams["productId"] = productId
            guard let product = ProductDetailParams(from: newParams) else { return nil }
            return .route(.productDetail(params: product))
        }

        if let orderId = URLParser.matchPattern("/order/:orderId", path: path)?["orderId"] {
            var newParams = params
            newParams["orderId"] = orderId
            guard let order = OrderDetailParams(from: newParams) else { return nil }
            return .route(.orderDetail(params: order))
        }

        return nil
    }

    private static func validate(_ intent: AppNavigationIntent, path: String, originalURL: URL) -> AppNavigationIntent {
        guard case .route(let route) = intent else {
            return intent
        }

        guard AppRouteRegistry.shared.validate(route) else {
            return .notFound(path: path, originalURL: AppPrivacyRedactor.redactedURLString(originalURL))
        }
        return intent
    }
}
