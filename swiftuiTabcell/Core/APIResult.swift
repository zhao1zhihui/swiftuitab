import Foundation

enum APIError: Error, Sendable {
    case network(String)
    case decoding(String)
    case emptyData
    case server(code: Int, message: String)
    case cancelled
    case unknown(String)

    var message: String {
        switch self {
        case .network(let message):
            return message
        case .decoding(let message):
            return "数据解析失败: \(message)"
        case .emptyData:
            return "暂无数据"
        case .server(_, let message):
            return message
        case .cancelled:
            return "请求已取消"
        case .unknown(let message):
            return message
        }
    }
}

enum APIResult<Value> {
    case success(Value)
    case failure(APIError)

    func map<T>(_ transform: (Value) -> T) -> APIResult<T> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
}

extension APIResult: Sendable where Value: Sendable {}

struct PageResult<Item> {
    let items: [Item]
    let page: Int
    let pageSize: Int
    let hasMore: Bool

    func mapItems<T>(_ transform: (Item) -> T) -> PageResult<T> {
        PageResult<T>(items: items.map(transform), page: page, pageSize: pageSize, hasMore: hasMore)
    }
}

extension PageResult: Sendable where Item: Sendable {}
