import Foundation
import Combine

struct AuthTokens: Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
}

@MainActor
final class AppSession: ObservableObject {
    static let shared = AppSession()

    @Published private(set) var isLoggedIn = false
    @Published private(set) var accessToken: String?

    private var refreshToken: String?
    private var refreshTask: Task<APIResult<AuthTokens>, Never>?

    private init() {}

    func login(username: String, password: String) async -> Bool {
        guard !username.isEmpty, !password.isEmpty else {
            return false
        }

        try? await Task.sleep(nanoseconds: 200_000_000)
        applyTokens(
            AuthTokens(
                accessToken: "access-\(UUID().uuidString)",
                refreshToken: "refresh-\(UUID().uuidString)"
            )
        )
        return true
    }

    func logout() {
        isLoggedIn = false
        accessToken = nil
        refreshToken = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshAccessTokenIfNeeded(
        using operation: @escaping (String) async -> APIResult<AuthTokens>
    ) async -> Bool {
        if let refreshTask {
            return await consumeRefreshTask(refreshTask)
        }

        guard let refreshToken else {
            return false
        }

        let task = Task<APIResult<AuthTokens>, Never> {
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
            applyTokens(tokens)
            return true
        case .failure:
            return false
        }
    }

    private func applyTokens(_ tokens: AuthTokens) {
        isLoggedIn = true
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
    }
}
