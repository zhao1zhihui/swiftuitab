import Foundation

nonisolated enum AppLogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

nonisolated struct AnalyticsEvent: Sendable {
    let name: String
    let metadata: [String: String]

    init(name: String, metadata: [String: String] = [:]) {
        self.name = name
        self.metadata = metadata
    }
}

nonisolated struct AppReportedError: Sendable {
    let source: String
    let message: String
    let metadata: [String: String]

    init(source: String, message: String, metadata: [String: String] = [:]) {
        self.source = source
        self.message = message
        self.metadata = metadata
    }
}

nonisolated enum AppPrivacyRedactor {
    private static let sensitiveKeys: Set<String> = [
        "token",
        "accesstoken",
        "refreshtoken",
        "password",
        "pwd",
        "secret",
        "authorization"
    ]

    /// 日志和埋点里不能直接输出 token、密码等敏感 query。
    /// 这里保留 URL 结构，只把敏感 value 替换掉，方便排查问题又不泄漏隐私。
    static func redactedURLString(_ url: URL?) -> String {
        guard let url else {
            return ""
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              !queryItems.isEmpty
        else {
            return url.absoluteString
        }

        components.queryItems = queryItems.map { item in
            guard sensitiveKeys.contains(item.name.lowercased()) else {
                return item
            }
            return URLQueryItem(name: item.name, value: "***")
        }
        return components.string ?? url.absoluteString
    }
}

/// 应用日志协议。
/// 业务代码只依赖协议，后续可以从 Console 切到 OSLog、文件日志或远端日志平台。
nonisolated protocol AppLogging: Sendable {
    func log(_ level: AppLogLevel, category: String, _ message: String, metadata: [String: String])
}

/// 埋点协议。
/// 先把事件出口定下来，具体接神策、Firebase 或公司内部 SDK 时不需要改业务层。
nonisolated protocol AnalyticsTracking: Sendable {
    func track(_ event: AnalyticsEvent)
}

/// 错误上报协议。
/// ViewModel/Router/Repository 只报告“哪里出了什么错”，不直接依赖第三方崩溃平台。
nonisolated protocol ErrorReporting: Sendable {
    func report(_ error: AppReportedError)
}

nonisolated struct ConsoleAppLogger: AppLogging {
    func log(_ level: AppLogLevel, category: String, _ message: String, metadata: [String: String] = [:]) {
        let metadataText = metadata.isEmpty ? "" : " \(metadata)"
        print("[\(level.rawValue.uppercased())] [\(category)] \(message)\(metadataText)")
    }
}

nonisolated struct ConsoleAnalyticsTracker: AnalyticsTracking {
    private let logger: any AppLogging

    init(logger: any AppLogging) {
        self.logger = logger
    }

    func track(_ event: AnalyticsEvent) {
        logger.log(.info, category: "analytics", event.name, metadata: event.metadata)
    }
}

nonisolated struct ConsoleErrorReporter: ErrorReporting {
    private let logger: any AppLogging

    init(logger: any AppLogging) {
        self.logger = logger
    }

    func report(_ error: AppReportedError) {
        logger.log(.error, category: "error.\(error.source)", error.message, metadata: error.metadata)
    }
}

/// 横切观测能力聚合。
/// 组合根统一创建它，避免日志、埋点、错误上报在各业务模块里各写各的。
nonisolated struct AppObservability: Sendable {
    let logger: any AppLogging
    let analytics: any AnalyticsTracking
    let errorReporter: any ErrorReporting

    static func makeConsole() -> AppObservability {
        let logger = ConsoleAppLogger()
        return AppObservability(
            logger: logger,
            analytics: ConsoleAnalyticsTracker(logger: logger),
            errorReporter: ConsoleErrorReporter(logger: logger)
        )
    }

    func track(_ name: String, metadata: [String: String] = [:]) {
        analytics.track(AnalyticsEvent(name: name, metadata: metadata))
    }

    func report(_ error: APIError, source: String, metadata: [String: String] = [:]) {
        errorReporter.report(
            AppReportedError(
                source: source,
                message: error.message,
                metadata: metadata
            )
        )
    }
}
