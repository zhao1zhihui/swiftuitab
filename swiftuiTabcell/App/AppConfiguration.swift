import Foundation

nonisolated struct FeatureFlags: Sendable {
    let usesLocalNetworkTransport: Bool
    let usesSecureTokenStore: Bool
    let enablesVerboseLogging: Bool
    let enablesMemoryCache: Bool

    static func defaults(for environment: AppEnvironment) -> FeatureFlags {
        switch environment {
        case .development:
            return FeatureFlags(
                usesLocalNetworkTransport: true,
                usesSecureTokenStore: false,
                enablesVerboseLogging: true,
                enablesMemoryCache: true
            )
        case .staging:
            return FeatureFlags(
                usesLocalNetworkTransport: false,
                usesSecureTokenStore: true,
                enablesVerboseLogging: true,
                enablesMemoryCache: true
            )
        case .production:
            return FeatureFlags(
                usesLocalNetworkTransport: false,
                usesSecureTokenStore: true,
                enablesVerboseLogging: false,
                enablesMemoryCache: true
            )
        }
    }
}

/// App 级配置。
/// 环境、开关、超时这类“提前要定的东西”集中在这里，避免散落在 ViewModel 和网络请求里。
nonisolated struct AppConfiguration: Sendable {
    let environment: AppEnvironment
    let featureFlags: FeatureFlags
    let networkTimeout: TimeInterval
    let feedCacheTTL: TimeInterval

    init(environment: AppEnvironment = .current,
         featureFlags: FeatureFlags? = nil,
         networkTimeout: TimeInterval = 30,
         feedCacheTTL: TimeInterval = 5 * 60) {
        self.environment = environment
        self.featureFlags = featureFlags ?? .defaults(for: environment)
        self.networkTimeout = networkTimeout
        self.feedCacheTTL = feedCacheTTL
    }
}

#if DEBUG
@MainActor
extension AppDependencies {
    /// Preview/样例入口统一从这里拿依赖。
    /// 后续新增页面时不要在 Preview 里手写单例或真实网络，直接复用这套开发环境依赖。
    static func preview() -> AppDependencies {
        AppDependencies(configuration: AppConfiguration(environment: .development))
    }
}
#endif
