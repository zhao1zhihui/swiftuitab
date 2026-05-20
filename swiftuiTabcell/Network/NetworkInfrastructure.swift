import Foundation

nonisolated enum RequestMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

nonisolated struct NetworkEndpoint: Sendable {
    let path: String
    let method: RequestMethod
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: Data? = nil
    var requiresAuthentication = false
    var timeoutInterval: TimeInterval = 15
}

nonisolated struct TransportResponse: Sendable {
    let statusCode: Int
    let data: Data
}

nonisolated protocol NetworkTransport {
    func send(_ request: URLRequest, endpoint: NetworkEndpoint) async -> APIResult<TransportResponse>
}

nonisolated protocol NetworkLogging {
    func logRequest(_ request: URLRequest)
    func logResponse(_ response: TransportResponse, request: URLRequest)
    func logFailure(_ error: APIError, request: URLRequest)
}

nonisolated protocol PayloadCrypto {
    func encrypt(_ data: Data) throws -> Data
    func decrypt(_ data: Data) throws -> Data
}

/// 控制台日志只是默认实现，生产项目可以替换成 OSLog/埋点平台/文件日志。
nonisolated struct ConsoleNetworkLogger: NetworkLogging {
    func logRequest(_ request: URLRequest) {
        print("[NETWORK] [Request] \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
    }

    func logResponse(_ response: TransportResponse, request: URLRequest) {
        print("[NETWORK] [Response] \(response.statusCode) \(request.url?.absoluteString ?? "")")
    }

    func logFailure(_ error: APIError, request: URLRequest) {
        print("[NETWORK] [Failure] \(request.url?.absoluteString ?? "") - \(error.message)")
    }
}

/// 网络层日志适配器。
/// NetworkService 仍只认识 NetworkLogging，真正日志出口由 AppObservability 统一管理。
nonisolated struct AppNetworkLogger: NetworkLogging {
    private let logger: any AppLogging

    init(logger: any AppLogging) {
        self.logger = logger
    }

    func logRequest(_ request: URLRequest) {
        logger.log(
            .debug,
            category: "network",
            "request",
            metadata: [
                "method": request.httpMethod ?? "GET",
                "requestId": request.value(forHTTPHeaderField: "X-Request-Id") ?? "",
                "url": AppPrivacyRedactor.redactedURLString(request.url)
            ]
        )
    }

    func logResponse(_ response: TransportResponse, request: URLRequest) {
        logger.log(
            .debug,
            category: "network",
            "response",
            metadata: [
                "requestId": request.value(forHTTPHeaderField: "X-Request-Id") ?? "",
                "statusCode": String(response.statusCode),
                "url": AppPrivacyRedactor.redactedURLString(request.url)
            ]
        )
    }

    func logFailure(_ error: APIError, request: URLRequest) {
        logger.log(
            .error,
            category: "network",
            error.message,
            metadata: [
                "requestId": request.value(forHTTPHeaderField: "X-Request-Id") ?? "",
                "url": AppPrivacyRedactor.redactedURLString(request.url)
            ]
        )
    }
}

/// 默认不加解密，保留接口是为了让金融/政企类项目可以在边界处统一接入加密。
nonisolated struct PassthroughCrypto: PayloadCrypto {
    func encrypt(_ data: Data) throws -> Data {
        data
    }

    func decrypt(_ data: Data) throws -> Data {
        data
    }
}

/// 真实网络传输层，只负责 URLSession I/O，不关心业务 code、token 和 DTO 解码。
nonisolated struct URLSessionNetworkTransport: NetworkTransport {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest, endpoint: NetworkEndpoint) async -> APIResult<TransportResponse> {
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.network("服务器响应无效"))
            }
            return .success(TransportResponse(statusCode: httpResponse.statusCode, data: data))
        } catch is CancellationError {
            return .failure(.cancelled)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}

nonisolated struct RefreshRequestBody: Codable, Sendable {
    let refreshToken: String
}

nonisolated struct RefreshResponseEnvelope: Codable, Sendable {
    let code: Int
    let message: String
    let data: RefreshResponseData?
}

nonisolated struct RefreshResponseData: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
}

nonisolated struct LocalNetworkTransport: NetworkTransport {
    private let responseDelay: Duration
    private let clock: any AppClock
    private let uuidGenerator: any UUIDGenerating

    init(responseDelay: Duration = .milliseconds(800),
         clock: any AppClock = SystemAppClock(),
         uuidGenerator: any UUIDGenerating = SystemUUIDGenerator()) {
        self.responseDelay = responseDelay
        self.clock = clock
        self.uuidGenerator = uuidGenerator
    }

    func send(_ request: URLRequest, endpoint: NetworkEndpoint) async -> APIResult<TransportResponse> {
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }

        do {
            try await clock.sleep(for: TimeInterval(responseDelay.components.seconds) + TimeInterval(responseDelay.components.attoseconds) / 1_000_000_000_000_000_000)
        } catch {
            return .failure(.cancelled)
        }

        switch endpoint.path {
        case "/feed":
            // 本地 mock 数据只服务 development 环境，方便 UI 和分页逻辑脱离后端调试。
            return .success(TransportResponse(statusCode: 200, data: LocalFeedDataStore.data))
        case "/auth/refresh":
            guard
                let body = request.httpBody,
                let payload = try? JSONDecoder().decode(RefreshRequestBody.self, from: body),
                payload.refreshToken.hasPrefix("refresh-")
            else {
                let data = Data(#"{"code":401,"message":"refresh token 无效","data":null}"#.utf8)
                return .success(TransportResponse(statusCode: 401, data: data))
            }

            let nextTokenSet = RefreshResponseEnvelope(
                code: 0,
                message: "ok",
                data: RefreshResponseData(
                    accessToken: "access-\(uuidGenerator.makeUUID().uuidString)",
                    refreshToken: "refresh-\(uuidGenerator.makeUUID().uuidString)"
                )
            )

            guard let data = try? JSONEncoder().encode(nextTokenSet) else {
                return .failure(.unknown("本地 refresh mock 编码失败"))
            }

            return .success(TransportResponse(statusCode: 200, data: data))
        default:
            return .failure(.server(code: 404, message: "未找到接口: \(endpoint.path)"))
        }
    }
}
