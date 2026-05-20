import XCTest
@testable import swiftuiTabcell

final class swiftuiTabcellTests: XCTestCase {
    func testRouteParserMatchesUserPath() throws {
        let url = try XCTUnwrap(URL(string: "ftlending://user/123?name=zhangsan"))
        let intent = try XCTUnwrap(AppRouteParser.parse(url))

        guard case .route(.profile(let params)) = intent else {
            return XCTFail("Expected profile route")
        }

        XCTAssertEqual(params.userId, "123")
        XCTAssertEqual(params.userName, "zhangsan")
    }

    func testRouteParserMatchesProductDetailPath() throws {
        let url = try XCTUnwrap(URL(string: "ftlending://product/detail?id=12345&name=iPhone&price=5999"))
        let intent = try XCTUnwrap(AppRouteParser.parse(url))

        guard case .route(.productDetail(let params)) = intent else {
            return XCTFail("Expected product detail route")
        }

        XCTAssertEqual(params.productId, "12345")
        XCTAssertEqual(params.productName, "iPhone")
        XCTAssertEqual(params.price, 5999)
    }

    func testRouteParserReturnsNotFoundForUnknownPath() throws {
        let url = try XCTUnwrap(URL(string: "ftlending://mystery/path?token=abc123"))
        let intent = try XCTUnwrap(AppRouteParser.parse(url))

        guard case .notFound(let path, let originalURL) = intent else {
            return XCTFail("Expected not found intent")
        }

        XCTAssertEqual(path, "/mystery/path")
        XCTAssertTrue(originalURL.contains("token=***"))
        XCTAssertFalse(originalURL.contains("abc123"))
    }

    func testAppConfigurationDefaultsMatchEnvironment() {
        let development = AppConfiguration(environment: .development)
        XCTAssertTrue(development.featureFlags.usesLocalNetworkTransport)
        XCTAssertFalse(development.featureFlags.usesSecureTokenStore)
        XCTAssertTrue(development.featureFlags.enablesMemoryCache)

        let production = AppConfiguration(environment: .production)
        XCTAssertFalse(production.featureFlags.usesLocalNetworkTransport)
        XCTAssertTrue(production.featureFlags.usesSecureTokenStore)
        XCTAssertFalse(production.featureFlags.enablesVerboseLogging)
    }

    @MainActor
    func testRouterDefersProtectedRouteUntilLoginSucceeds() async {
        let session = AppSession(tokenStore: InMemoryTokenStore())
        let router = AppRouter(session: session)

        await router.navigate(to: .orders)

        XCTAssertEqual(router.selectedTab, .account)
        XCTAssertEqual(router.accountPath, [.login])

        let didLogin = await session.login(username: "user", password: "password")
        XCTAssertTrue(didLogin)

        await router.handleLoginSuccess()

        XCTAssertEqual(router.selectedTab, .account)
        XCTAssertEqual(router.accountPath, [.orders])
    }

    @MainActor
    func testSessionRestoresTokensFromInjectedStore() async {
        let tokenStore = InMemoryTokenStore()
        let uuidGenerator = FixedUUIDGenerator(
            uuids: [
                UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
            ]
        )
        let session = AppSession(tokenStore: tokenStore, uuidGenerator: uuidGenerator, clock: ImmediateClock())

        let didLogin = await session.login(username: "user", password: "password")
        XCTAssertTrue(didLogin)
        XCTAssertEqual(session.accessToken, "access-00000000-0000-0000-0000-000000000001")

        let restoredSession = AppSession(tokenStore: tokenStore)
        await restoredSession.restoreSession()

        XCTAssertTrue(restoredSession.isLoggedIn)
        XCTAssertNotNil(restoredSession.accessToken)

        await restoredSession.logout()

        let clearedSession = AppSession(tokenStore: tokenStore)
        await clearedSession.restoreSession()
        XCTAssertFalse(clearedSession.isLoggedIn)
        XCTAssertNil(clearedSession.accessToken)
    }

    @MainActor
    func testRouterShowsBackConfirmationAndConfirmsPop() async {
        let session = AppSession(tokenStore: InMemoryTokenStore())
        let router = AppRouter(session: session)
        let lockedRoute = AppRoute.basic(
            params: BasicPageParams(
                canGestureBack: false,
                needLogin: false,
                title: "受保护流程"
            )
        )

        await router.navigate(to: lockedRoute)
        XCTAssertEqual(router.discoverPath, [lockedRoute])

        router.applyNavigationPath([], on: .discover)

        XCTAssertEqual(router.discoverPath, [lockedRoute])
        XCTAssertEqual(router.backAlert?.title, "当前页面不能直接返回")

        router.confirmBlockedBack()

        XCTAssertTrue(router.discoverPath.isEmpty)
        XCTAssertNil(router.backAlert)
    }

    @MainActor
    func testRouterCancelsBackConfirmationWithoutChangingPath() async {
        let session = AppSession(tokenStore: InMemoryTokenStore())
        let router = AppRouter(session: session)
        let lockedRoute = AppRoute.basic(
            params: BasicPageParams(
                canGestureBack: false,
                needLogin: false,
                title: "受保护流程"
            )
        )

        await router.navigate(to: lockedRoute)
        router.applyNavigationPath([], on: .discover)
        router.cancelBlockedBack()

        XCTAssertEqual(router.discoverPath, [lockedRoute])
        XCTAssertNil(router.backAlert)
    }

    @MainActor
    func testRouterBlocksInteractiveBackBeforeGestureBegins() async {
        let session = AppSession(tokenStore: InMemoryTokenStore())
        let router = AppRouter(session: session)
        let lockedRoute = AppRoute.basic(
            params: BasicPageParams(
                canGestureBack: false,
                needLogin: false,
                title: "侧滑拦截"
            )
        )

        await router.navigate(to: lockedRoute)
        let shouldBegin = router.shouldBeginInteractiveBack(from: lockedRoute, on: .discover)

        XCTAssertFalse(shouldBegin)
        XCTAssertEqual(router.discoverPath, [lockedRoute])
        XCTAssertEqual(router.backAlert?.title, "当前页面不能直接返回")

        router.confirmBlockedBack()
        XCTAssertTrue(router.discoverPath.isEmpty)
    }

    func testGestureConflictDemoRouteUsesHorizontalScrollHandoffPolicy() {
        let directRoute = AppRoute.gestureConflictDemo(mode: .directAtLeadingEdge)
        let secondSwipeRoute = AppRoute.gestureConflictDemo(mode: .secondSwipeAtLeadingEdge)

        XCTAssertEqual(directRoute.preferredTab, .discover)
        XCTAssertTrue(directRoute.backPolicy.allowsSystemBack)
        XCTAssertEqual(directRoute.backPolicy.horizontalScrollHandoff, .directAtLeadingEdge)
        XCTAssertEqual(secondSwipeRoute.backPolicy.horizontalScrollHandoff, .secondSwipeAtLeadingEdge)
    }

    func testRouteRegistryContainsExpectedEntries() {
        XCTAssertTrue(AppRouteRegistry.shared.validate(.settings))
        XCTAssertTrue(AppRouteRegistry.shared.validate(.gestureConflictDemo(mode: .directAtLeadingEdge)))
        XCTAssertTrue(AppRouteRegistry.shared.validate(.routeNotFound(path: "/sample")))
    }

    func testPrivacyRedactorMasksSensitiveQueryParameters() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/path?token=abc123&name=zhangsan"))
        let redacted = AppPrivacyRedactor.redactedURLString(url)

        XCTAssertTrue(redacted.contains("token=***"))
        XCTAssertTrue(redacted.contains("name=zhangsan"))
        XCTAssertFalse(redacted.contains("abc123"))
    }

    @MainActor
    func testFeedViewModelRefreshUsesInjectedProvider() async {
        let provider = StubCardProvider(
            result: .success(
                PageResult(
                    items: [
                        .text(TextRowModel(id: 1, title: "Injected", subtitle: "Provider"))
                    ],
                    page: 0,
                    pageSize: 10,
                    hasMore: false
                )
            )
        )
        let viewModel = FeedScreenViewModel(provider: provider)

        await viewModel.refreshContent()

        XCTAssertEqual(provider.requests, [PagingRequest(page: 0, pageSize: 10)])
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.pagePhase, .content)
        XCTAssertFalse(viewModel.canLoadMore)
    }

    func testErrorPresenterMapsNetworkErrorToRetryablePresentation() {
        let presenter = DefaultAppErrorPresenter()

        let presentation = presenter.presentation(for: .network("断网了"), id: "network.test")

        XCTAssertEqual(presentation.id, "network.test")
        XCTAssertEqual(presentation.title, "网络异常")
        XCTAssertEqual(presentation.message, "断网了")
        XCTAssertTrue(presentation.isRetryable)
    }

    @MainActor
    func testFeedRepositoryFallsBackToCacheWhenNetworkFails() async {
        let tokenStore = InMemoryTokenStore()
        let session = AppSession(tokenStore: tokenStore, clock: ImmediateClock())
        let networkService = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            transport: FailingNetworkTransport(),
            logger: SilentNetworkLogger(),
            crypto: PassthroughCrypto(),
            session: session
        )
        let cacheStore = InMemoryCacheStore()
        let repository = FeedRepository(
            networkService: networkService,
            cacheStore: cacheStore,
            clock: ImmediateClock(),
            cacheTTL: 60
        )
        await cacheStore.saveData(
            LocalFeedDataStore.data,
            for: CacheKey("feed.page.0.size.10"),
            ttl: 60,
            now: Date(timeIntervalSince1970: 0)
        )

        let result = await repository.fetchFeed(page: 0, pageSize: 10)

        guard case .success(let page) = result else {
            return XCTFail("Expected cached page")
        }
        XCTAssertEqual(page.items.count, 10)
        XCTAssertEqual(page.page, 0)
        XCTAssertTrue(page.hasMore)
    }

    @MainActor
    func testNetworkServiceAddsRequestIdAndTimeout() async throws {
        let session = AppSession(tokenStore: InMemoryTokenStore())
        let transport = RecordingNetworkTransport(data: Data("ok".utf8))
        let requestId = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let networkService = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            transport: transport,
            logger: SilentNetworkLogger(),
            crypto: PassthroughCrypto(),
            session: session,
            uuidGenerator: FixedUUIDGenerator(uuids: [requestId])
        )

        let result = await networkService.request(
            NetworkEndpoint(
                path: "/ping",
                method: .get,
                timeoutInterval: 7
            )
        )

        guard case .success(let data) = result else {
            return XCTFail("Expected success response")
        }
        XCTAssertEqual(data, Data("ok".utf8))

        let recordedRequests = await transport.recordedRequests()
        let request = try XCTUnwrap(recordedRequests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Request-Id"), requestId.uuidString)
        XCTAssertEqual(request.timeoutInterval, 7)
    }

    @MainActor
    func testNetworkServiceRefreshesTokenOnceAfterUnauthorizedResponse() async throws {
        let loginUUIDs = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        ]
        let session = AppSession(
            tokenStore: InMemoryTokenStore(),
            uuidGenerator: FixedUUIDGenerator(uuids: loginUUIDs),
            clock: ImmediateClock()
        )
        let didLogin = await session.login(username: "user", password: "password")
        XCTAssertTrue(didLogin)

        let transport = RefreshingNetworkTransport()
        let networkService = NetworkService(
            baseURL: URL(string: "https://example.com")!,
            transport: transport,
            logger: SilentNetworkLogger(),
            crypto: PassthroughCrypto(),
            session: session,
            uuidGenerator: FixedUUIDGenerator(
                uuids: [
                    UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                    UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                    UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
                ]
            )
        )

        let result = await networkService.request(
            NetworkEndpoint(
                path: "/protected",
                method: .get,
                requiresAuthentication: true
            )
        )

        guard case .success(let data) = result else {
            return XCTFail("Expected protected request to be replayed after refresh")
        }

        XCTAssertEqual(data, Data("ok".utf8))
        let protectedAuthHeaders = await transport.recordedProtectedAuthHeaders()
        XCTAssertEqual(
            protectedAuthHeaders,
            [
                "Bearer access-00000000-0000-0000-0000-000000000001",
                "Bearer access-refreshed"
            ]
        )
        XCTAssertEqual(session.accessToken, "access-refreshed")
    }

    @MainActor
    func testFeedViewModelUsesInjectedErrorPresenter() async {
        let provider = StubCardProvider(result: .failure(.network("offline")))
        let viewModel = FeedScreenViewModel(
            provider: provider,
            errorPresenter: FixedErrorPresenter(
                presentation: AppErrorPresentation(
                    id: "fixed",
                    title: "统一错误",
                    message: "请稍后再试",
                    actionTitle: "重试",
                    severity: .warning,
                    isRetryable: true
                )
            ),
            clock: ImmediateClock()
        )

        await viewModel.refreshContent()

        XCTAssertEqual(viewModel.pagePhase, .error(message: "请稍后再试"))
    }
}

private struct PagingRequest: Equatable {
    let page: Int
    let pageSize: Int
}

@MainActor
private final class StubCardProvider: CardProvider {
    // 测试替身：记录请求参数，同时返回预设结果，验证 ViewModel 是否真的走了依赖注入。
    private let result: APIResult<PageResult<FeedRow>>
    private(set) var requests: [PagingRequest] = []

    init(result: APIResult<PageResult<FeedRow>>) {
        self.result = result
    }

    func loadItems(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedRow>> {
        requests.append(PagingRequest(page: page, pageSize: pageSize))
        return result
    }
}

private struct ImmediateClock: AppClock {
    var now: Date {
        Date(timeIntervalSince1970: 0)
    }

    func sleep(for seconds: TimeInterval) async throws {}
}

private final class FixedUUIDGenerator: UUIDGenerating, @unchecked Sendable {
    private var uuids: [UUID]

    init(uuids: [UUID]) {
        self.uuids = uuids
    }

    func makeUUID() -> UUID {
        if uuids.isEmpty {
            return UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
        }
        return uuids.removeFirst()
    }
}

private struct FailingNetworkTransport: NetworkTransport {
    func send(_ request: URLRequest, endpoint: NetworkEndpoint) async -> APIResult<TransportResponse> {
        .failure(.network("offline"))
    }
}

private actor RecordingNetworkTransport: NetworkTransport {
    private let data: Data
    private var requests: [URLRequest] = []

    init(data: Data) {
        self.data = data
    }

    func send(_ request: URLRequest, endpoint: NetworkEndpoint) async -> APIResult<TransportResponse> {
        requests.append(request)
        return .success(TransportResponse(statusCode: 200, data: data))
    }

    func recordedRequests() -> [URLRequest] {
        return requests
    }
}

private actor RefreshingNetworkTransport: NetworkTransport {
    private var protectedAuthHeaders: [String] = []

    func send(_ request: URLRequest, endpoint: NetworkEndpoint) async -> APIResult<TransportResponse> {
        switch endpoint.path {
        case "/auth/refresh":
            let envelope = RefreshResponseEnvelope(
                code: 0,
                message: "ok",
                data: RefreshResponseData(
                    accessToken: "access-refreshed",
                    refreshToken: "refresh-refreshed"
                )
            )
            let data = (try? JSONEncoder().encode(envelope)) ?? Data()
            return .success(TransportResponse(statusCode: 200, data: data))
        default:
            protectedAuthHeaders.append(request.value(forHTTPHeaderField: "Authorization") ?? "")
            let attempt = protectedAuthHeaders.count

            if attempt == 1 {
                return .success(TransportResponse(statusCode: 401, data: Data()))
            }
            return .success(TransportResponse(statusCode: 200, data: Data("ok".utf8)))
        }
    }

    func recordedProtectedAuthHeaders() -> [String] {
        return protectedAuthHeaders
    }
}

private struct SilentNetworkLogger: NetworkLogging {
    func logRequest(_ request: URLRequest) {}
    func logResponse(_ response: TransportResponse, request: URLRequest) {}
    func logFailure(_ error: APIError, request: URLRequest) {}
}

private struct FixedErrorPresenter: AppErrorPresenting {
    let presentation: AppErrorPresentation

    func presentation(for error: APIError, id: String) -> AppErrorPresentation {
        presentation
    }
}
