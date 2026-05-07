//
//  SmartRouter.swift
//  简化版路由系统 - View 自己处理参数
//

import SwiftUI
import Combine

// MARK: - 路由协议

protocol Routable: Hashable {
    associatedtype Destination: View
    @ViewBuilder var view: Destination { get }
}

// MARK: - 参数模型（遵循 Hashable）

struct BasicPageParams: Hashable {
    let step: Int
    let canGestureBack: Bool
    let closeType: String
    let needLogin: Bool
    let title: String?
    
    init(step: Int = 1,
         canGestureBack: Bool = true,
         closeType: String = "myself",
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
        self.closeType = dict["closeType"] ?? "myself"
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
    
    init(from dict: [String: String]) {
        self.userId = dict["userId"] ?? dict["id"] ?? ""
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
    
    init(from dict: [String: String]) {
        self.productId = dict["productId"] ?? dict["id"] ?? ""
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
    
    init(from dict: [String: String]) {
        self.orderId = dict["orderId"] ?? dict["id"] ?? ""
        self.status = dict["status"]
    }
}

// MARK: - URL 解析器

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
        
        guard patternComponents.count == pathComponents.count else { return nil }
        
        var params: [String: String] = [:]
        for (patternComp, pathComp) in zip(patternComponents, pathComponents) {
            if patternComp.hasPrefix(":") {
                let paramName = String(patternComp.dropFirst())
                params[paramName] = String(pathComp)
            } else if patternComp != pathComp {
                return nil
            }
        }
        return params
    }
}

// MARK: - AppRoute 枚举（显式声明 Hashable）

enum AppRoute: Hashable, Routable {
    case home
    case settings
    case orders
    case login
    case detail(id: String, title: String)
    case basic(params: BasicPageParams)
    case productDetail(params: ProductDetailParams)
    case orderDetail(params: OrderDetailParams)
    case profile(params: ProfileParams)
    
    // MARK: - View 映射
    @ViewBuilder
    var view: some View {
        switch self {
        case .home:
            HomeView()
        case .settings:
            SettingsView()
        case .orders:
            OrdersView()
        case .login:
            LoginView()
        case .detail(let id, let title):
            DetailView(id: id, title: title)
        case .basic(let params):
            BasicView(params: params)
        case .productDetail(let params):
            ProductDetailView(params: params)
        case .orderDetail(let params):
            OrderDetailView(params: params)
        case .profile(let params):
            ProfileView(params: params)
        }
    }
    
    // MARK: - 是否需要登录
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
    
    // MARK: - URL 解析
    static func fromURL(_ url: URL) -> AppRoute? {
        let (path, params) = URLParser.parse(url)
        
        // 固定路径匹配
        switch path {
        case "/", "/home":
            return .home
        case "/settings":
            return .settings
        case "/orders":
            return .orders
        case "/login":
            return .login
        case "/profile":
            return .profile(params: ProfileParams(from: params))
        case "/product":
            return .productDetail(params: ProductDetailParams(from: params))
        case "/order":
            return .orderDetail(params: OrderDetailParams(from: params))
        case "/addition/basic":
            return .basic(params: BasicPageParams(from: params))
        default:
            break
        }
        
        // 动态路径匹配
        if let userId = URLParser.matchPattern("/user/:userId", path: path)?["userId"] {
            var newParams = params
            newParams["userId"] = userId
            return .profile(params: ProfileParams(from: newParams))
        }
        
        if let productId = URLParser.matchPattern("/product/:productId", path: path)?["productId"] {
            var newParams = params
            newParams["productId"] = productId
            return .productDetail(params: ProductDetailParams(from: newParams))
        }
        
        if let orderId = URLParser.matchPattern("/order/:orderId", path: path)?["orderId"] {
            var newParams = params
            newParams["orderId"] = orderId
            return .orderDetail(params: OrderDetailParams(from: newParams))
        }
        
        return nil
    }
}

// MARK: - 拦截结果

enum InterceptResult {
    case allow
    case redirect(to: any Routable)
    case cancel
}

// MARK: - 路由拦截器协议

protocol RouteInterceptor {
    func intercept(route: any Routable) async -> InterceptResult
}

// MARK: - 路由管理器

@MainActor
class Router<Route: Routable>: ObservableObject {
    
    @Published var path = NavigationPath()
    @Published var presentedRoute: Route?
    @Published var isPresenting = false
    
    private var interceptors: [RouteInterceptor] = []
    private var isNavigating = false
    private var pendingRoute: Route?
    
    nonisolated init() {}
    
    // MARK: - 注册拦截器
    func addInterceptor(_ interceptor: RouteInterceptor) {
        interceptors.append(interceptor)
    }
    
    // MARK: - 导航方法
    func push(_ route: Route) {
        Task { await push(to: route) }
    }
    
    func push(to route: Route) async {
        guard !isNavigating else { return }
        isNavigating = true
        
        let result = await executeInterceptors(for: route)
        
        switch result {
        case .allow:
            await MainActor.run {
                path.append(route)
            }
            isNavigating = false
            
        case .redirect(let newRoute):
            isNavigating = false
            if let newRoute = newRoute as? Route {
                if isLoginRoute(newRoute) {
                    pendingRoute = route
                    await push(to: newRoute)
                } else {
                    await push(to: newRoute)
                }
            }
            
        case .cancel:
            isNavigating = false
        }
    }
    
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    func popWithoutAnimation() {
        guard !path.isEmpty else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            path.removeLast()
        }
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
    
    func replaceRoot(with route: Route) async {
        popToRoot()
        await push(to: route)
    }
    
    func present(_ route: Route) async {
        presentedRoute = route
        isPresenting = true
    }
    
    func dismiss() {
        presentedRoute = nil
        isPresenting = false
    }
    
    func continuePendingRoute() {
        guard let pendingRoute = pendingRoute else { return }
        self.pendingRoute = nil
        Task {
            await push(to: pendingRoute)
        }
    }
    
    func clearPendingRoute() {
        pendingRoute = nil
    }
    
    func handleURL(_ url: URL) async -> Bool where Route == AppRoute {
        guard let route = AppRoute.fromURL(url) else {
            print("❌ 无法解析 URL: \(url)")
            return false
        }
        await push(to: route)
        return true
    }
    
    func handleURL(_ urlString: String) async -> Bool where Route == AppRoute {
        guard let url = URL(string: urlString) else {
            print("❌ 无效的 URL: \(urlString)")
            return false
        }
        return await handleURL(url)
    }
    
    // MARK: - Private
    private func executeInterceptors(for route: Route) async -> InterceptResult {
        for interceptor in interceptors {
            let result = await interceptor.intercept(route: route)
            if case .allow = result {
                continue
            }
            return result
        }
        return .allow
    }
    
    private func isLoginRoute(_ route: Route) -> Bool {
        let routeString = String(describing: route)
        return routeString.contains("login") || routeString.contains("Login")
    }
}

// MARK: - 路由视图容器

struct RouterView<Route: Routable>: View {
    @StateObject private var router: Router<Route>
    @ViewBuilder private let rootView: () -> Route.Destination
    
    init(router: Router<Route> = Router<Route>(), rootView: @autoclosure @escaping () -> Route.Destination) {
        self._router = StateObject(wrappedValue: router)
        self.rootView = rootView
    }
    
    var body: some View {
        NavigationStack(path: $router.path) {
            rootView()
                .navigationDestination(for: Route.self) { route in
                    route.view
                }
        }
        .sheet(isPresented: $router.isPresenting) {
            if let route = router.presentedRoute {
                route.view
            }
        }
        .environmentObject(router)
    }
}

// MARK: - 拦截器

struct AuthInterceptor: RouteInterceptor {
    private var isLoggedIn: Bool {
        UserDefaults.standard.bool(forKey: "isLoggedIn")
    }
    
    func intercept(route: any Routable) async -> InterceptResult {
        guard let appRoute = route as? AppRoute else {
            return .allow
        }
        
        if appRoute.requiresAuth && !isLoggedIn {
            print("🔐 需要登录，重定向到登录页")
            return .redirect(to: AppRoute.login)
        }
        
        return .allow
    }
}

struct LoggingInterceptor: RouteInterceptor {
    func intercept(route: any Routable) async -> InterceptResult {
        print("📱 路由请求: \(route)")
        return .allow
    }
}

// MARK: - 页面视图

struct HomeView: View {
    @EnvironmentObject var router: Router<AppRoute>
    
    var body: some View {
        List {
            Section("基础导航") {
                Button("基础页面") {
                    let params = BasicPageParams(
                        step: 1,
                        canGestureBack: false,
                        closeType: "myself",
                        needLogin: true,
                        title: "基础信息"
                    )
                    router.push(.basic(params: params))
                }
                
                Button("商品详情") {
                    let params = ProductDetailParams(
                        productId: "12345",
                        productName: "iPhone 15",
                        price: 5999
                    )
                    router.push(.productDetail(params: params))
                }
                
                Button("订单详情") {
                    let params = OrderDetailParams(
                        orderId: "ORDER001",
                        status: "待付款"
                    )
                    router.push(.orderDetail(params: params))
                }
                
                Button("个人资料") {
                    let params = ProfileParams(
                        userId: "123",
                        userName: "张三"
                    )
                    router.push(.profile(params: params))
                }
            }
            
            Section("URL 跳转测试") {
                Button("ftlending://addition/basic?step=1&canGestureBack=0&needLogin=1") {
                    Task {
                        await router.handleURL("ftlending://addition/basic?step=1&canGestureBack=0&needLogin=1")
                    }
                }
                
                Button("ftlending://product/detail?id=12345&name=iPhone&price=5999") {
                    Task {
                        await router.handleURL("ftlending://product/detail?id=12345&name=iPhone&price=5999")
                    }
                }
                
                Button("ftlending://user/123") {
                    Task {
                        await router.handleURL("ftlending://user/123")
                    }
                }
            }
            
            Section("登录状态") {
                Button("模拟登录") {
                    UserDefaults.standard.set(true, forKey: "isLoggedIn")
                    print("✅ 已登录")
                }
                
                Button("模拟登出") {
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                    print("❌ 已登出")
                }
            }
        }
        .navigationTitle("首页")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("设置") {
                    router.push(.settings)
                }
            }
        }
    }
}

struct BasicView: View {
    let params: BasicPageParams
    @EnvironmentObject var router: Router<AppRoute>
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text(params.title ?? "基础页面")
                .font(.largeTitle)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("step: \(params.step)")
                Text("canGestureBack: \(params.canGestureBack ? "支持" : "不支持")")
                Text("closeType: \(params.closeType)")
                Text("needLogin: \(params.needLogin ? "需要" : "不需要")")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Button("下一步") {
                let nextParams = BasicPageParams(
                    step: params.step + 1,
                    canGestureBack: params.canGestureBack,
                    closeType: params.closeType,
                    needLogin: params.needLogin,
                    title: params.title
                )
                router.push(.basic(params: nextParams))
            }
            .buttonStyle(.borderedProminent)
            
            Button("关闭") {
                if params.closeType == "myself" {
                    dismiss()
                } else if params.closeType == "root" {
                    router.popToRoot()
                } else {
                    router.pop()
                }
            }
        }
        .padding()
        .navigationTitle("Step \(params.step)")
        .interactiveDismissDisabled(!params.canGestureBack)
    }
}

struct ProductDetailView: View {
    let params: ProductDetailParams
    @EnvironmentObject var router: Router<AppRoute>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("商品详情")
                .font(.largeTitle)
            Text("商品ID: \(params.productId)")
            if let name = params.productName {
                Text("商品名: \(name)")
            }
            if let price = params.price {
                Text("价格: ¥\(price)")
            }
            
            Button("返回") {
                router.pop()
            }
        }
        .navigationTitle(params.productName ?? "商品详情")
    }
}

struct OrderDetailView: View {
    let params: OrderDetailParams
    @EnvironmentObject var router: Router<AppRoute>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("订单详情")
                .font(.largeTitle)
            Text("订单ID: \(params.orderId)")
            if let status = params.status {
                Text("状态: \(status)")
            }
            
            Button("返回") {
                router.pop()
            }
        }
        .navigationTitle("订单详情")
    }
}

struct ProfileView: View {
    let params: ProfileParams
    @EnvironmentObject var router: Router<AppRoute>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("个人资料")
                .font(.largeTitle)
            Text("用户ID: \(params.userId)")
            if let name = params.userName {
                Text("姓名: \(name)")
            }
            
            Button("返回") {
                router.pop()
            }
        }
        .navigationTitle(params.userName ?? "个人资料")
    }
}

struct SettingsView: View {
    @EnvironmentObject var router: Router<AppRoute>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("设置页面")
                .font(.largeTitle)
            Button("返回") {
                router.pop()
            }
        }
        .navigationTitle("设置")
    }
}

struct OrdersView: View {
    @EnvironmentObject var router: Router<AppRoute>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("我的订单")
                .font(.largeTitle)
            Button("返回") {
                router.pop()
            }
        }
        .navigationTitle("订单")
    }
}

struct LoginView: View {
    @EnvironmentObject var router: Router<AppRoute>
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("登录")
                .font(.largeTitle)
            
            TextField("用户名", text: $username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
            
            SecureField("密码", text: $password)
                .textFieldStyle(.roundedBorder)
            
            Button("登录") {
                login()
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || password.isEmpty)
        }
        .padding()
        .navigationTitle("登录")
    }
    
    private func login() {
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        print("✅ 登录成功")
        
        router.popWithoutAnimation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            router.continuePendingRoute()
        }
    }
}

struct DetailView: View {
    let id: String
    let title: String
    @EnvironmentObject var router: Router<AppRoute>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("详情页面")
                .font(.largeTitle)
            Text("ID: \(id)")
            Button("返回") {
                router.pop()
            }
        }
        .navigationTitle(title)
    }
}

// MARK: - App 入口

@main
struct MyApp: App {
    let router = Router<AppRoute>()
    
    init() {
        router.addInterceptor(LoggingInterceptor())
        router.addInterceptor(AuthInterceptor())
    }
    
    var body: some Scene {
        WindowGroup {
            RouterView(router: router, rootView: AppRoute.home.view)
                .onOpenURL { url in
                    Task {
                        await router.handleURL(url)
                    }
                }
        }
    }
}
