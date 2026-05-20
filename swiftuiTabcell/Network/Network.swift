import Foundation

nonisolated private enum AuthAPI {
    static func refreshToken(_ refreshToken: String) -> NetworkEndpoint {
        let requestBody = RefreshRequestBody(refreshToken: refreshToken)
        let data = try? JSONEncoder().encode(requestBody)
        return NetworkEndpoint(
            path: "/auth/refresh",
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: data,
            requiresAuthentication: false
        )
    }
}

nonisolated enum FeedAPI {
    case feed(page: Int, pageSize: Int)

    var endpoint: NetworkEndpoint {
        switch self {
        case .feed(let page, let pageSize):
            return NetworkEndpoint(
                path: "/feed",
                method: .get,
                queryItems: [
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "pageSize", value: String(pageSize))
                ]
            )
        }
    }
}

/// 非 UI 网络服务。
/// 项目开启了 Swift 6 默认 MainActor 隔离，所以这里显式 nonisolated，确保请求构建、传输、解码不被主 actor 绑定。
/// 该类型只持有不可变依赖；可变登录态交给 AppSession 的 MainActor 管理，因此可以安全跨任务传递。
nonisolated final class NetworkService: @unchecked Sendable {
    private let baseURL: URL
    private let transport: any NetworkTransport
    private let logger: any NetworkLogging
    private let crypto: any PayloadCrypto
    private let session: AppSession
    private let uuidGenerator: any UUIDGenerating

    /// 所有可变基础设施都从外部注入，方便测试时替换 transport/logger/crypto/session。
    init(baseURL: URL,
         transport: any NetworkTransport = LocalNetworkTransport(),
         logger: any NetworkLogging = ConsoleNetworkLogger(),
         crypto: any PayloadCrypto = PassthroughCrypto(),
         session: AppSession,
         uuidGenerator: any UUIDGenerating = SystemUUIDGenerator()) {
        self.baseURL = baseURL
        self.transport = transport
        self.logger = logger
        self.crypto = crypto
        self.session = session
        self.uuidGenerator = uuidGenerator
    }

    func request(_ target: FeedAPI) async -> APIResult<Data> {
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }

        return await request(target.endpoint)
    }

    func request(_ endpoint: NetworkEndpoint, retryOnAuthFailure: Bool = true) async -> APIResult<Data> {
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }

        let requestResult = await makeURLRequest(for: endpoint)
        switch requestResult {
        case .failure(let error):
            return .failure(error)
        case .success(let urlRequest):
            logger.logRequest(urlRequest)
            let responseResult = await transport.send(urlRequest, endpoint: endpoint)

            switch responseResult {
            case .failure(let error):
                logger.logFailure(error, request: urlRequest)
                return .failure(error)
            case .success(let response):
                logger.logResponse(response, request: urlRequest)

                if response.statusCode == 401, endpoint.requiresAuthentication, retryOnAuthFailure {
                    // token 刷新由 AppSession 串行协调；刷新成功后只重试一次，防止无限 401 循环。
                    let refreshed = await session.refreshAccessTokenIfNeeded { [weak self] refreshToken in
                        guard let self else {
                            return .failure(.unknown("网络服务已释放，无法刷新 token"))
                        }
                        return await self.refreshTokens(with: refreshToken)
                    }
                    guard refreshed else {
                        await session.logout()
                        return .failure(.server(code: 401, message: "登录已过期，请重新登录"))
                    }
                    return await request(endpoint, retryOnAuthFailure: false)
                }

                guard (200..<300).contains(response.statusCode) else {
                    return .failure(.server(code: response.statusCode, message: "请求失败"))
                }

                do {
                    return .success(try crypto.decrypt(response.data))
                } catch {
                    return .failure(.unknown("响应解密失败: \(error.localizedDescription)"))
                }
            }
        }
    }

    /// 只在需要鉴权时跨 actor 读取 accessToken，其余请求构建逻辑保持在非 UI 上下文。
    private func makeURLRequest(for endpoint: NetworkEndpoint) async -> APIResult<URLRequest> {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        components?.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems

        guard let url = components?.url else {
            return .failure(.unknown("无效的请求地址"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeoutInterval
        request.setValue(uuidGenerator.makeUUID().uuidString, forHTTPHeaderField: "X-Request-Id")

        endpoint.headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if endpoint.requiresAuthentication {
            let accessToken = await session.accessToken
            if let accessToken {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
        }

        if let body = endpoint.body {
            do {
                request.httpBody = try crypto.encrypt(body)
            } catch {
                return .failure(.unknown("请求加密失败: \(error.localizedDescription)"))
            }
        }

        return .success(request)
    }

    /// refresh 接口复用同一套 request/transport/crypto 流程，但它本身不再触发二次 refresh。
    private func refreshTokens(with refreshToken: String) async -> APIResult<AuthTokens> {
        let endpoint = AuthAPI.refreshToken(refreshToken)
        let requestResult = await makeURLRequest(for: endpoint)

        switch requestResult {
        case .failure(let error):
            return .failure(error)
        case .success(let urlRequest):
            logger.logRequest(urlRequest)
            let responseResult = await transport.send(urlRequest, endpoint: endpoint)

            switch responseResult {
            case .failure(let error):
                logger.logFailure(error, request: urlRequest)
                return .failure(error)
            case .success(let response):
                logger.logResponse(response, request: urlRequest)

                guard (200..<300).contains(response.statusCode) else {
                    return .failure(.server(code: response.statusCode, message: "刷新 token 失败"))
                }

                do {
                    let decryptedData = try crypto.decrypt(response.data)
                    let envelope = try JSONDecoder().decode(RefreshResponseEnvelope.self, from: decryptedData)

                    guard envelope.code == 0, let data = envelope.data else {
                        return .failure(.server(code: envelope.code, message: envelope.message))
                    }

                    return .success(
                        AuthTokens(
                            accessToken: data.accessToken,
                            refreshToken: data.refreshToken
                        )
                    )
                } catch {
                    return .failure(.unknown("刷新 token 解析失败: \(error.localizedDescription)"))
                }
            }
        }
    }
}
