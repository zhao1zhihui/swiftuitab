import Foundation

private enum AuthAPI {
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

enum FeedAPI {
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

@MainActor
final class NetworkService {
    static let shared = NetworkService(session: AppSession.shared)

    private let baseURL = URL(string: "https://stub.swiftui-tabcell.local")!
    private let transport: any NetworkTransport
    private let logger: any NetworkLogging
    private let crypto: any PayloadCrypto
    private let session: AppSession

    init(transport: any NetworkTransport = LocalNetworkTransport(),
         logger: any NetworkLogging = ConsoleNetworkLogger(),
         crypto: any PayloadCrypto = PassthroughCrypto(),
         session: AppSession) {
        self.transport = transport
        self.logger = logger
        self.crypto = crypto
        self.session = session
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
                    let refreshed = await session.refreshAccessTokenIfNeeded { [weak self] refreshToken in
                        guard let self else {
                            return .failure(.unknown("网络服务已释放，无法刷新 token"))
                        }
                        return await self.refreshTokens(with: refreshToken)
                    }
                    guard refreshed else {
                        session.logout()
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

    private func makeURLRequest(for endpoint: NetworkEndpoint) async -> APIResult<URLRequest> {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        components?.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems

        guard let url = components?.url else {
            return .failure(.unknown("无效的请求地址"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        endpoint.headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if endpoint.requiresAuthentication {
            let accessToken = session.accessToken
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

private struct LocalFeedEnvelope<Item: Codable>: Codable {
    let code: Int
    let message: String
    let data: LocalFeedPage<Item>?
}

private struct LocalFeedPage<Item: Codable>: Codable {
    let items: [Item]
}

@MainActor
final class FeedRepository {
    func fetchFeed(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedItem>> {
        let result = await NetworkService.shared.request(.feed(page: page, pageSize: pageSize))
        switch result {
        case .success(let data):
            return makePageResult(from: data, itemType: FeedItem.self, page: page, pageSize: pageSize)
        case .failure(let error):
            return .failure(error)
        }
    }

    func fetchFeedRaw(page: Int, pageSize: Int) async -> APIResult<PageResult<FeedRaw>> {
        let result = await NetworkService.shared.request(.feed(page: page, pageSize: pageSize))
        switch result {
        case .success(let data):
            return makePageResult(from: data, itemType: FeedRaw.self, page: page, pageSize: pageSize)
        case .failure(let error):
            return .failure(error)
        }
    }

    private func makePageResult<Item: Codable>(from data: Data,
                                               itemType: Item.Type,
                                               page: Int,
                                               pageSize: Int) -> APIResult<PageResult<Item>> {
        do {
            _ = itemType
            let response = try JSONDecoder().decode(LocalFeedEnvelope<Item>.self, from: data)
            guard response.code == 0 else {
                return .failure(.server(code: response.code, message: response.message))
            }
            guard let allItems = response.data?.items else {
                return .failure(.emptyData)
            }
            let startIndex = page * pageSize
            guard startIndex < allItems.count else {
                return .success(PageResult(items: [], page: page, pageSize: pageSize, hasMore: false))
            }
            let endIndex = min(startIndex + pageSize, allItems.count)
            let pagedItems = Array(allItems[startIndex..<endIndex])
            return .success(
                PageResult(
                    items: pagedItems,
                    page: page,
                    pageSize: pageSize,
                    hasMore: endIndex < allItems.count
                )
            )
        } catch {
            return .failure(.decoding(error.localizedDescription))
        }
    }
}
