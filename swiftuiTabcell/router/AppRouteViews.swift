import SwiftUI

struct FeedTabRootView: View {
    var body: some View {
        ContentView()
    }
}

struct DiscoverTabRootView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        List {
            Section("基础导航") {
                Button("基础页面") {
                    router.push(
                        .basic(
                            params: BasicPageParams(
                                step: 1,
                                canGestureBack: false,
                                closeType: .myself,
                                needLogin: true,
                                title: "基础信息"
                            )
                        )
                    )
                }

                Button("商品详情") {
                    router.push(
                        .productDetail(
                            params: ProductDetailParams(
                                productId: "12345",
                                productName: "iPhone 15",
                                price: 5999
                            )
                        )
                    )
                }

                Button("订单详情") {
                    router.push(
                        .orderDetail(
                            params: OrderDetailParams(
                                orderId: "ORDER001",
                                status: "待付款"
                            )
                        )
                    )
                }
            }

            Section("URL 跳转测试") {
                Button("ftlending://addition/basic?step=1&canGestureBack=0&needLogin=1") {
                    Task {
                        await router.handleURL(URL(string: "ftlending://addition/basic?step=1&canGestureBack=0&needLogin=1")!)
                    }
                }

                Button("ftlending://product/detail?id=12345&name=iPhone&price=5999") {
                    Task {
                        await router.handleURL(URL(string: "ftlending://product/detail?id=12345&name=iPhone&price=5999")!)
                    }
                }

                Button("ftlending://user/123?name=zhangsan") {
                    Task {
                        await router.handleURL(URL(string: "ftlending://user/123?name=zhangsan")!)
                    }
                }
            }
        }
        .navigationTitle("发现")
    }
}

struct AccountTabRootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var session: AppSession

    var body: some View {
        List {
            Section("账户") {
                if session.isLoggedIn {
                    Label("已登录", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("未登录", systemImage: "person.crop.circle.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
            }

            Section("我的功能") {
                Button("我的订单") {
                    router.push(.orders)
                }

                Button("个人资料") {
                    router.push(.profile(params: ProfileParams(userId: "123", userName: "张三")))
                }

                Button("设置") {
                    router.push(.settings)
                }
            }

            Section("登录状态") {
                if session.isLoggedIn {
                    Button("退出登录", role: .destructive) {
                        session.logout()
                        router.clearProtectedContinuation()
                    }
                } else {
                    Button("去登录") {
                        router.push(.login)
                    }
                }
            }
        }
        .navigationTitle("我的")
    }
}

struct RouteDestinationView: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .settings:
            SettingsView()
        case .orders:
            OrdersView()
        case .login:
            LoginView()
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
}

struct BasicView: View {
    let params: BasicPageParams

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(spacing: 20) {
            Text(params.title ?? "基础页面")
                .font(.largeTitle)

            VStack(alignment: .leading, spacing: 10) {
                Text("step: \(params.step)")
                Text("canGestureBack: \(params.canGestureBack ? "支持" : "不支持")")
                Text("closeType: \(params.closeType.rawValue)")
                Text("needLogin: \(params.needLogin ? "需要" : "不需要")")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("下一步") {
                router.push(
                    .basic(
                        params: BasicPageParams(
                            step: params.step + 1,
                            canGestureBack: params.canGestureBack,
                            closeType: params.closeType,
                            needLogin: params.needLogin,
                            title: params.title
                        )
                    )
                )
            }
            .buttonStyle(.borderedProminent)

            Button("关闭") {
                switch params.closeType {
                case .myself:
                    dismiss()
                case .parent:
                    router.pop(on: .discover)
                case .root:
                    router.popToRoot(on: .discover)
                }
            }
        }
        .padding()
        .navigationTitle("Step \(params.step)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProductDetailView: View {
    let params: ProductDetailParams

    var body: some View {
        VStack(spacing: 20) {
            Text("商品详情")
                .font(.largeTitle)
            Text("商品ID: \(params.productId)")
            if let productName = params.productName {
                Text("商品名: \(productName)")
            }
            if let price = params.price {
                Text("价格: ¥\(price, specifier: "%.2f")")
            }
        }
        .padding()
        .navigationTitle(params.productName ?? "商品详情")
    }
}

struct OrderDetailView: View {
    let params: OrderDetailParams

    var body: some View {
        VStack(spacing: 20) {
            Text("订单详情")
                .font(.largeTitle)
            Text("订单ID: \(params.orderId)")
            if let status = params.status {
                Text("状态: \(status)")
            }
        }
        .padding()
        .navigationTitle("订单详情")
    }
}

struct ProfileView: View {
    let params: ProfileParams

    var body: some View {
        VStack(spacing: 20) {
            Text("个人资料")
                .font(.largeTitle)
            Text("用户ID: \(params.userId)")
            if let userName = params.userName {
                Text("姓名: \(userName)")
            }
        }
        .padding()
        .navigationTitle(params.userName ?? "个人资料")
    }
}

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("设置页面")
                .font(.largeTitle)
            Text("这里可以继续接通用配置、日志开关和网络环境切换。")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("设置")
    }
}

struct OrdersView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("我的订单")
                .font(.largeTitle)
            Text("订单列表页可以继续对接真正的分页接口。")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("订单")
    }
}

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isSubmitting = false

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var session: AppSession

    var body: some View {
        VStack(spacing: 20) {
            Text("登录")
                .font(.largeTitle)

            TextField("用户名", text: $username)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("密码", text: $password)
                .textFieldStyle(.roundedBorder)

            Button {
                submitLogin()
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("登录")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || password.isEmpty || isSubmitting)
        }
        .padding()
        .navigationTitle("登录")
    }

    private func submitLogin() {
        guard !isSubmitting else { return }
        isSubmitting = true

        Task {
            let success = await session.login(username: username, password: password)
            await MainActor.run {
                isSubmitting = false
            }

            if success {
                await router.handleLoginSuccess()
            }
        }
    }
}
