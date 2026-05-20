import SwiftUI

struct FeedTabRootView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        ContentView(viewModel: dependencies.makeFeedScreenViewModel())
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

                Button("侧滑返回拦截 Demo") {
                    router.push(
                        .basic(
                            params: BasicPageParams(
                                step: 1,
                                canGestureBack: false,
                                closeType: .myself,
                                needLogin: false,
                                title: "侧滑返回拦截 Demo"
                            )
                        )
                    )
                }

                Button("横向 Scroll 直接返回 Demo") {
                    router.push(.gestureConflictDemo(mode: .directAtLeadingEdge))
                }

                Button("横向 Scroll 二次滑动返回 Demo") {
                    router.push(.gestureConflictDemo(mode: .secondSwipeAtLeadingEdge))
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
                        Task {
                            await session.logout()
                            router.clearProtectedContinuation()
                        }
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
        case .routeNotFound(let path):
            RouteNotFoundView(path: path)
        case .basic(let params):
            BasicView(params: params)
        case .gestureConflictDemo(let mode):
            GestureConflictDemoView(mode: mode)
        case .productDetail(let params):
            ProductDetailView(params: params)
        case .orderDetail(let params):
            OrderDetailView(params: params)
        case .profile(let params):
            ProfileView(params: params)
        }
    }
}

struct RouteNotFoundView: View {
    let path: String

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(spacing: AppSpacing.l) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("页面不存在")
                .font(AppTypography.pageTitle)

            Text("未找到可处理的路径：\(path)")
                .font(AppTypography.cardBody)
                .foregroundStyle(AppColor.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                router.pop(on: .discover)
            } label: {
                Label("返回发现", systemImage: "arrow.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(AppSpacing.xxl)
        .navigationTitle("页面不存在")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GestureConflictDemoView: View {
    let mode: HorizontalScrollBackHandoff

    @EnvironmentObject private var router: AppRouter

    private var title: String {
        switch mode {
        case .directAtLeadingEdge:
            return "直接返回"
        case .secondSwipeAtLeadingEdge:
            return "二次滑动返回"
        }
    }

    private var description: String {
        switch mode {
        case .directAtLeadingEdge:
            return "横向列表已经滑到最左边时，再向右滑会直接交给页面返回。"
        case .secondSwipeAtLeadingEdge:
            return "横向列表已经滑到最左边时，第一次右滑留给列表，短时间内第二次右滑才交给页面返回。"
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text("全屏返回和横向 Scroll 冲突 Demo")
                        .font(.title2.bold())
                    Text(description)
                        .font(AppTypography.cardBody)
                        .foregroundStyle(AppColor.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.l)
                .background(AppColor.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))

                ForEach(0..<5, id: \.self) { section in
                    horizontalSection(index: section)
                }

                Button {
                    router.pop(on: .discover)
                } label: {
                    Label("页面内关闭", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(AppSpacing.l)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func horizontalSection(index: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("横向模块 \(index + 1)")
                .font(AppTypography.cardTitle)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: AppSpacing.m) {
                    ForEach(0..<12, id: \.self) { item in
                        horizontalCard(section: index, item: item)
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.vertical, AppSpacing.s)
            }
            .background(AppColor.subtleBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        }
    }

    @ViewBuilder
    private func horizontalCard(section: Int, item: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Day \(item + 1)")
                .font(.headline)
            Text(item % 3 == 0 ? "已签到" : "待完成")
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.86))
            Spacer()
            Image(systemName: item % 2 == 0 ? "checkmark.seal.fill" : "gift.fill")
                .font(.title2)
        }
        .foregroundStyle(.white)
        .padding(AppSpacing.m)
        .frame(width: 132, height: 112, alignment: .leading)
        .background(cardColor(section: section, item: item))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func cardColor(section: Int, item: Int) -> Color {
        let colors: [Color] = [
            .blue,
            .green,
            .teal,
            .indigo,
            .pink,
            .cyan
        ]
        return colors[(section + item) % colors.count]
    }
}

struct BasicView: View {
    let params: BasicPageParams

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(spacing: 20) {
            Text(params.title ?? "基础页面")
                .font(AppTypography.pageTitle)

            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("step: \(params.step)")
                Text("canGestureBack: \(params.canGestureBack ? "支持" : "不支持")")
                Text("closeType: \(params.closeType.rawValue)")
                Text("needLogin: \(params.needLogin ? "需要" : "不需要")")
            }
            .padding(AppSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.subtleBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))

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
                    router.pop(on: .discover)
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
                .font(AppTypography.pageTitle)
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
                .font(AppTypography.pageTitle)
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
                .font(AppTypography.pageTitle)
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
                .font(AppTypography.pageTitle)
            Text("这里可以继续接通用配置、日志开关和网络环境切换。")
                .foregroundStyle(AppColor.secondaryText)
        }
        .padding()
        .navigationTitle("设置")
    }
}

struct OrdersView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("我的订单")
                .font(AppTypography.pageTitle)
            Text("订单列表页可以继续对接真正的分页接口。")
                .foregroundStyle(AppColor.secondaryText)
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
                .font(AppTypography.pageTitle)

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
