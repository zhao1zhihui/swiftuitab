import Foundation
import Combine

/// 应用运行环境。
/// 团队项目里所有 baseURL、mock/真实网络、环境开关都应该从这里收口，避免散落在业务代码里。
nonisolated enum AppEnvironment: Sendable {
    case development
    case staging
    case production

    var baseURL: URL {
        switch self {
        case .development:
            return URL(string: "https://stub.swiftui-tabcell.local")!
        case .staging:
            return URL(string: "https://staging.swiftui-tabcell.local")!
        case .production:
            return URL(string: "https://api.swiftui-tabcell.local")!
        }
    }

    var usesLocalTransport: Bool {
        switch self {
        case .development:
            return true
        case .staging, .production:
            return false
        }
    }

    var usesSecureTokenStore: Bool {
        switch self {
        case .development:
            return false
        case .staging, .production:
            return true
        }
    }

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

@MainActor
final class AppDependencies: ObservableObject {
    let configuration: AppConfiguration
    let environment: AppEnvironment
    let session: AppSession
    let router: AppRouter
    let observability: AppObservability
    let clock: any AppClock
    let uuidGenerator: any UUIDGenerating
    let cacheStore: any CacheStore
    let errorPresenter: any AppErrorPresenting
    let networkService: NetworkService
    let feedRepository: FeedRepository
    let cardProvider: CardProvider

    /// 应用组合根。
    /// 只在这里创建具体实现，Feature 层只接收协议或已经组装好的对象，方便替换 mock、写单测和切环境。
    init(configuration: AppConfiguration = AppConfiguration(),
         environment: AppEnvironment? = nil,
         session: AppSession? = nil) {
        let resolvedConfiguration = environment.map { AppConfiguration(environment: $0) } ?? configuration
        let resolvedObservability = AppObservability.makeConsole()
        let resolvedClock: any AppClock = SystemAppClock()
        let resolvedUUIDGenerator: any UUIDGenerating = SystemUUIDGenerator()
        let resolvedErrorPresenter: any AppErrorPresenting = DefaultAppErrorPresenter()
        let resolvedCacheStore: any CacheStore = resolvedConfiguration.featureFlags.enablesMemoryCache
            ? InMemoryCacheStore()
            : NullCacheStore()

        // token 存储也从组合根选择：开发用内存避免污染调试环境，正式环境用 Keychain 保证安全落盘。
        let tokenStore: any TokenStore = resolvedConfiguration.featureFlags.usesSecureTokenStore
            ? KeychainTokenStore()
            : InMemoryTokenStore()
        let resolvedSession = session ?? AppSession(
            tokenStore: tokenStore,
            uuidGenerator: resolvedUUIDGenerator,
            clock: resolvedClock
        )

        // development 默认使用本地 mock transport，staging/production 才走真实 URLSession。
        let transport: any NetworkTransport = resolvedConfiguration.featureFlags.usesLocalNetworkTransport
            ? LocalNetworkTransport(clock: resolvedClock, uuidGenerator: resolvedUUIDGenerator)
            : URLSessionNetworkTransport()

        let resolvedNetworkService = NetworkService(
            baseURL: resolvedConfiguration.environment.baseURL,
            transport: transport,
            logger: AppNetworkLogger(logger: resolvedObservability.logger),
            crypto: PassthroughCrypto(),
            session: resolvedSession,
            uuidGenerator: resolvedUUIDGenerator
        )
        let resolvedFeedRepository = FeedRepository(
            networkService: resolvedNetworkService,
            cacheStore: resolvedCacheStore,
            clock: resolvedClock,
            cacheTTL: resolvedConfiguration.feedCacheTTL
        )
        let resolvedCardProvider = EnumCardProvider(repository: resolvedFeedRepository)
        let resolvedRouter = AppRouter(session: resolvedSession, observability: resolvedObservability)

        self.configuration = resolvedConfiguration
        self.environment = resolvedConfiguration.environment
        self.observability = resolvedObservability
        self.clock = resolvedClock
        self.uuidGenerator = resolvedUUIDGenerator
        self.errorPresenter = resolvedErrorPresenter
        self.cacheStore = resolvedCacheStore
        self.session = resolvedSession
        self.networkService = resolvedNetworkService
        self.feedRepository = resolvedFeedRepository
        self.cardProvider = resolvedCardProvider
        self.router = resolvedRouter
    }

    /// 每次进入首页时创建新的 ViewModel，依赖仍然复用同一套仓库和服务。
    func makeFeedScreenViewModel() -> FeedScreenViewModel {
        FeedScreenViewModel(
            provider: cardProvider,
            observability: observability,
            errorPresenter: errorPresenter,
            clock: clock
        )
    }
}
