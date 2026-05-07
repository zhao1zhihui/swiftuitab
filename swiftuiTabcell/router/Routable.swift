//
//  SmartRouter.swift
//  智能路由系统 - 支持拦截器、钩子、路由映射
//
//  Created on 2026-01-18
//

 import SwiftUI
 import Combine

// MARK: - 路由协议

/// 路由协议（类型安全）
protocol Routable: Hashable, Identifiable {
    associatedtype Destination: View
    
    var id: String { get }
    
    @ViewBuilder
    var view: Destination { get }
}

extension Routable {
    var id: String { String(describing: Self.self) }
}

// MARK: - 拦截结果

/// 拦截结果
enum InterceptResult {
    case allow                    // 允许跳转
    case redirect(to: any Routable)  // 重定向到其他路由
    case cancel                   // 取消跳转
}

// MARK: - 路由拦截器协议

/// 路由拦截器 - 可以阻止或重定向跳转
protocol RouteInterceptor {
    /// 拦截方法，返回结果决定是否继续跳转
    func intercept(route: any Routable) async -> InterceptResult
}

// MARK: - 路由钩子协议

/// 路由钩子 - 只能观察，不能改变跳转流程
/// 注意：钩子方法运行在 MainActor 上，可以安全修改 UI 状态
@MainActor
protocol RouteHook {
    /// 跳转前调用（在主线程）
    func willNavigate(to route: any Routable)
    
    /// 跳转后调用（在主线程）
    func didNavigate(to route: any Routable)
}

// MARK: - 路由管理器

@MainActor
class Router<Route: Routable>: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 导航路径
    @Published var path = NavigationPath()
    
    /// 当前展示的模态页面
    @Published var presentedRoute: Route?
    
    /// 是否正在展示模态
    @Published var isPresenting = false
    
    // MARK: - Private Properties
    
    /// 拦截器列表（按添加顺序执行）
    private var interceptors: [RouteInterceptor] = []
    
    /// 钩子列表（按添加顺序执行）
    private var hooks: [RouteHook] = []
    
    /// 是否正在导航中
    private var isNavigating = false
    
    // MARK: - Initialization
    
    public nonisolated init() {}
    
    // MARK: - 注册方法
    
    /// 添加拦截器（按添加顺序执行）
    public func addInterceptor(_ interceptor: RouteInterceptor) {
        interceptors.append(interceptor)
    }
    
    /// 移除所有拦截器
    public func removeAllInterceptors() {
        interceptors.removeAll()
    }
    
    /// 添加钩子（按添加顺序执行）
    public func addHook(_ hook: RouteHook) {
        hooks.append(hook)
    }
    
    /// 移除所有钩子
    public func removeAllHooks() {
        hooks.removeAll()
    }
    
    // MARK: - 导航方法
    
    /// Push 新页面（异步，支持拦截器中的异步操作）
    public func push(to route: Route) async {
        await navigate(to: route)
    }
    
    /// Push 新页面（同步，简单场景使用）
    public func push(_ route: Route) {
        Task {
            await push(to: route)
        }
    }
    
    /// 返回上一页
    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    /// 返回到根页面
    public func popToRoot() {
        path.removeLast(path.count)
    }
    
    /// 替换根视图（清空导航栈后 Push）
    public func replaceRoot(with route: Route) async {
        popToRoot()
        await push(to: route)
    }
    
    /// 模态展示页面
    public func present(_ route: Route) async {
        let result = await executeInterceptors(for: route)
        
        switch result {
        case .allow:
            presentedRoute = route
            isPresenting = true
            executeDidNavigateHooks(for: route)
            
        case .redirect(let newRoute):
            if let newRoute = newRoute as? Route {
                await present(newRoute)
            }
            
        case .cancel:
            break
        }
    }
    
    /// 关闭模态
    public func dismiss() {
        presentedRoute = nil
        isPresenting = false
    }
    
    // MARK: - Private Methods
    
    private func navigate(to route: Route) async {
        guard !isNavigating else { return }
        isNavigating = true
        defer { isNavigating = false }
        
        // 执行拦截器
        let result = await executeInterceptors(for: route)
        
        switch result {
        case .allow:
            // 执行跳转前钩子
            executeWillNavigateHooks(for: route)
            
            // 执行跳转
            path.append(route)
            
            // 执行跳转后钩子
            executeDidNavigateHooks(for: route)
            
        case .redirect(let newRoute):
            if let newRoute = newRoute as? Route {
                await navigate(to: newRoute)
            }
            
        case .cancel:
            break
        }
    }
    
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
    
    private func executeWillNavigateHooks(for route: Route) {
        for hook in hooks {
            hook.willNavigate(to: route)
        }
    }
    
    private func executeDidNavigateHooks(for route: Route) {
        for hook in hooks {
            hook.didNavigate(to: route)
        }
    }
}

// MARK: - 路由视图容器

/// 路由视图容器 - 在 App 入口使用
struct RouterView<Route: Routable>: View {
    @StateObject private var router: Router<Route>
    @ViewBuilder private let rootView: () -> Route.Destination
    
    public init(router: Router<Route> = Router<Route>(), rootView: @autoclosure @escaping () -> Route.Destination) {
        self._router = StateObject(wrappedValue: router)
        self.rootView = rootView
    }
    
    public var body: some View {
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

// MARK: - View 扩展

extension View {
    /// 获取路由环境对象
    func router<Route: Routable>() -> some View {
        self.environmentObject(Router<Route>())
    }
}

// MARK: - ============================================
// MARK: - 使用示例
// MARK: - ============================================

// 1. 定义路由枚举
enum AppRoute: Routable {
    case home
    case profile(userId: String)
    case settings
    case orders
    case login
    
    @ViewBuilder
    var view: some View {
        switch self {
        case .home:
            HomeView()
        case .profile(let userId):
            ProfileView(userId: userId)
        case .settings:
            SettingsView()
        case .orders:
            OrdersView()
        case .login:
            LoginView()
        }
    }
    
    // 辅助属性：是否需要登录
    var requiresAuth: Bool {
        switch self {
        case .orders, .profile:
            return true
        default:
            return false
        }
    }
}

// MARK: - 拦截器示例

/// 登录拦截器 - 检查是否需要登录
struct AuthInterceptor: RouteInterceptor {
    private var isLoggedIn: Bool {
        UserDefaults.standard.bool(forKey: "isLoggedIn")
    }
    
    func intercept(route: any Routable) async -> InterceptResult {
        guard let route = route as? AppRoute else {
            return .allow
        }
        
        if route.requiresAuth && !isLoggedIn {
            print("🔐 需要登录，重定向到登录页")
            return .redirect(to: AppRoute.login)
        }
        
        return .allow
    }
}

/// 日志拦截器 - 打印路由请求
struct LoggingInterceptor: RouteInterceptor {
    func intercept(route: any Routable) async -> InterceptResult {
        print("📱 路由请求: \(route)")
        return .allow
    }
}

// MARK: - 钩子示例

/// 埋点钩子
struct AnalyticsHook: RouteHook {
    func willNavigate(to route: any Routable) {
        print("📊 埋点: 开始跳转 \(route)")
    }
    
    func didNavigate(to route: any Routable) {
        print("📊 埋点: 完成跳转 \(route)")
    }
}

/// 性能监控钩子 - 使用 class 解决可变状态问题
@MainActor
final class PerformanceHook: RouteHook {
    private var startTime: Date?
    
    nonisolated init() {}
    
    func willNavigate(to route: any Routable) {
        startTime = Date()
        print("⏱️ 开始计时: \(route)")
    }
    
    func didNavigate(to route: any Routable) {
        guard let startTime = startTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        print("⏱️ 跳转耗时: \(String(format: "%.3f", duration))秒 - \(route)")
    }
}

// MARK: - 页面视图

struct HomeView: View {
    @EnvironmentObject var router: Router<AppRoute>
    
    var body: some View {
        List {
            Section("公开页面") {
                Button("去个人资料（需要登录）") {
                    router.push(.profile(userId: "123"))
                }
                Button("去设置") {
                    router.push(.settings)
                }
            }
            
            Section("需要登录的页面") {
                Button("我的订单") {
                    router.push(.orders)
                }
            }
        }
        .navigationTitle("首页")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("登录") {
                    router.push(.login)
                }
            }
        }
    }
}

struct ProfileView: View {
    let userId: String
    @EnvironmentObject var router: Router<AppRoute>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("个人资料")
                .font(.largeTitle)
            Text("用户ID: \(userId)")
            
            Button("返回") {
                router.pop()
            }
            
            Button("回首页") {
                Task {
                    await router.replaceRoot(with: .home)
                }
            }
        }
        .navigationTitle("资料")
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
        // 模拟登录成功
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        print("✅ 登录成功")
        
        // 返回上一页
        router.pop()
    }
}

// MARK: - App 入口

//@main
struct MyApp: App {
    // 创建路由实例
    let router = Router<AppRoute>()
    
    init() {
        // 注册拦截器（按添加顺序执行）
        router.addInterceptor(LoggingInterceptor())  // 先记录日志
        router.addInterceptor(AuthInterceptor())     // 再检查登录
        
        // 注册钩子（按添加顺序执行）
        router.addHook(AnalyticsHook())   // 埋点统计
        
        // ✅ 使用 class 而不是 struct，可以修改自身属性
        let performanceHook = PerformanceHook()
        router.addHook(performanceHook)
    }
    
    var body: some Scene {
        WindowGroup {
            RouterView(router: router, rootView: AppRoute.home.view)
        }
    }
}
