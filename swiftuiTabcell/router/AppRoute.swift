import Foundation
import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
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

struct BasicPageParams: Hashable {
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

struct ProfileParams: Hashable {
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

struct ProductDetailParams: Hashable {
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

struct OrderDetailParams: Hashable {
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

enum AppRoute: Hashable, Identifiable {
    case settings
    case orders
    case login
    case basic(params: BasicPageParams)
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
        case .basic(let params):
            return "basic-\(params.step)-\(params.needLogin)-\(params.closeType.rawValue)-\(params.title ?? "")"
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
        case .basic, .productDetail, .orderDetail:
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
}

enum AppNavigationIntent {
    case tab(AppTab)
    case route(AppRoute)
}

struct URLParser {
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

enum AppRouteParser {
    static func parse(_ url: URL) -> AppNavigationIntent? {
        let (path, params) = URLParser.parse(url)

        switch path {
        case "/", "/home":
            return .tab(.feed)
        case "/discover":
            return .tab(.discover)
        case "/account":
            return .tab(.account)
        case "/settings":
            return .route(.settings)
        case "/orders":
            return .route(.orders)
        case "/login":
            return .route(.login)
        case "/profile":
            guard let profile = ProfileParams(from: params) else { return nil }
            return .route(.profile(params: profile))
        case "/product":
            guard let product = ProductDetailParams(from: params) else { return nil }
            return .route(.productDetail(params: product))
        case "/order":
            guard let order = OrderDetailParams(from: params) else { return nil }
            return .route(.orderDetail(params: order))
        case "/addition/basic":
            return .route(.basic(params: BasicPageParams(from: params)))
        default:
            break
        }

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
}
