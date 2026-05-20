import Foundation
import Combine

nonisolated struct AuthTokens: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
}

/// 登录态只负责 UI 可观察状态和 token 刷新协调。
/// token 的持久化交给 TokenStore 协议，避免 ViewModel/网络层直接碰 Keychain 或单例。
@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var isLoggedIn = false
    @Published private(set) var accessToken: String?

    private var refreshToken: String?
    private var refreshTask: Task<APIResult<AuthTokens>, Never>?
    private let tokenStore: any TokenStore
    private let uuidGenerator: any UUIDGenerating
    private let clock: any AppClock

    init(tokenStore: any TokenStore = InMemoryTokenStore(),
         uuidGenerator: any UUIDGenerating = SystemUUIDGenerator(),
         clock: any AppClock = SystemAppClock()) {
        self.tokenStore = tokenStore
        self.uuidGenerator = uuidGenerator
        self.clock = clock
    }

    /// App 启动时恢复登录态。
    /// 组合根决定 token 从 Keychain 还是内存读取，Session 只负责把结果同步到 UI 状态。
    func restoreSession() async {
        guard !isLoggedIn else {
            return
        }

        do {
            guard let tokens = try await tokenStore.loadTokens() else {
                return
            }
            applyLoadedTokens(tokens)
        } catch {
            await clearStoredTokens()
        }
    }

    func login(username: String, password: String) async -> Bool {
        guard !username.isEmpty, !password.isEmpty else {
            return false
        }

        // 登录接口目前是本地模拟，也走可注入时钟；以后接真实接口时测试不需要改等待逻辑。
        try? await clock.sleep(for: 0.2)
        let tokens = AuthTokens(
            accessToken: "access-\(uuidGenerator.makeUUID().uuidString)",
            refreshToken: "refresh-\(uuidGenerator.makeUUID().uuidString)"
        )
        return await applyAndPersistTokens(tokens)
    }

    func logout() async {
        isLoggedIn = false
        accessToken = nil
        refreshToken = nil
        refreshTask?.cancel()
        refreshTask = nil
        await clearStoredTokens()
    }

    func refreshAccessTokenIfNeeded(
        using operation: @escaping @Sendable (String) async -> APIResult<AuthTokens>
    ) async -> Bool {
        // 多个接口同时遇到 401 时复用同一个刷新任务，避免并发刷新把 token 互相覆盖。
        if let refreshTask {
            return await consumeRefreshTask(refreshTask)
        }

        guard let refreshToken else {
            return false
        }

        let task = Task.detached(priority: .userInitiated) {
            await operation(refreshToken)
        }

        refreshTask = task
        return await consumeRefreshTask(task)
    }

    private func consumeRefreshTask(_ task: Task<APIResult<AuthTokens>, Never>) async -> Bool {
        let result = await task.value
        refreshTask = nil

        switch result {
        case .success(let tokens):
            return await applyAndPersistTokens(tokens)
        case .failure:
            return false
        }
    }

    /// refresh/login 成功后先落盘再更新 UI，避免界面显示已登录但下次启动无法恢复。
    private func applyAndPersistTokens(_ tokens: AuthTokens) async -> Bool {
        do {
            try await tokenStore.saveTokens(tokens)
            applyLoadedTokens(tokens)
            return true
        } catch {
            return false
        }
    }

    private func applyLoadedTokens(_ tokens: AuthTokens) {
        isLoggedIn = true
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
    }

    private func clearStoredTokens() async {
        do {
            try await tokenStore.clearTokens()
        } catch {
            // 清理失败时仍保持 UI 退出态；后续可以在这里接入日志系统上报安全存储异常。
        }
    }
}
