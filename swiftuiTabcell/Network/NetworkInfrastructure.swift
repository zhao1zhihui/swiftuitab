import Foundation

enum RequestMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

struct NetworkEndpoint: Sendable {
    let path: String
    let method: RequestMethod
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: Data? = nil
    var requiresAuthentication = false
}

struct TransportResponse: Sendable {
    let statusCode: Int
    let data: Data
}

protocol NetworkTransport {
    func send(_ request: URLRequest, endpoint: NetworkEndpoint) async -> APIResult<TransportResponse>
}

protocol NetworkLogging {
    func logRequest(_ request: URLRequest)
    func logResponse(_ response: TransportResponse, request: URLRequest)
    func logFailure(_ error: APIError, request: URLRequest)
}

protocol PayloadCrypto {
    func encrypt(_ data: Data) throws -> Data
    func decrypt(_ data: Data) throws -> Data
}

struct ConsoleNetworkLogger: NetworkLogging {
    func logRequest(_ request: URLRequest) {
        print("🌐 [Request] \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
    }

    func logResponse(_ response: TransportResponse, request: URLRequest) {
        print("✅ [Response] \(response.statusCode) \(request.url?.absoluteString ?? "")")
    }

    func logFailure(_ error: APIError, request: URLRequest) {
        print("❌ [Failure] \(request.url?.absoluteString ?? "") - \(error.message)")
    }
}

struct PassthroughCrypto: PayloadCrypto {
    func encrypt(_ data: Data) throws -> Data {
        data
    }

    func decrypt(_ data: Data) throws -> Data {
        data
    }
}

struct RefreshRequestBody: Codable, Sendable {
    let refreshToken: String
}

struct RefreshResponseEnvelope: Codable, Sendable {
    let code: Int
    let message: String
    let data: RefreshResponseData?
}

struct RefreshResponseData: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
}

struct LocalNetworkTransport: NetworkTransport {
    private let responseDelay: Duration

    init(responseDelay: Duration = .milliseconds(800)) {
        self.responseDelay = responseDelay
    }

    func send(_ request: URLRequest, endpoint: NetworkEndpoint) async -> APIResult<TransportResponse> {
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }

        do {
            try await Task.sleep(for: responseDelay)
        } catch {
            return .failure(.cancelled)
        }

        switch endpoint.path {
        case "/feed":
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
                    accessToken: "access-\(UUID().uuidString)",
                    refreshToken: "refresh-\(UUID().uuidString)"
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
