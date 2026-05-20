import Foundation

nonisolated enum AppErrorSeverity: String, Sendable {
    case info
    case warning
    case error
}

nonisolated struct AppErrorPresentation: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let message: String
    let actionTitle: String
    let severity: AppErrorSeverity
    let isRetryable: Bool
}

/// 错误展示协议。
/// Repository/网络层只抛业务错误，页面展示文案统一从这里生成，避免每个 ViewModel 自己拼弹窗。
nonisolated protocol AppErrorPresenting: Sendable {
    func presentation(for error: APIError, id: String) -> AppErrorPresentation
}

nonisolated struct DefaultAppErrorPresenter: AppErrorPresenting {
    func presentation(for error: APIError, id: String) -> AppErrorPresentation {
        switch error {
        case .network(let message):
            return AppErrorPresentation(
                id: id,
                title: "网络异常",
                message: message.isEmpty ? "网络连接失败，请稍后重试" : message,
                actionTitle: "重试",
                severity: .warning,
                isRetryable: true
            )
        case .decoding:
            return AppErrorPresentation(
                id: id,
                title: "数据异常",
                message: error.message,
                actionTitle: "重试",
                severity: .error,
                isRetryable: true
            )
        case .emptyData:
            return AppErrorPresentation(
                id: id,
                title: "暂无数据",
                message: error.message,
                actionTitle: "重新加载",
                severity: .info,
                isRetryable: true
            )
        case .server(let code, let message) where code == 401:
            return AppErrorPresentation(
                id: id,
                title: "登录已过期",
                message: message.isEmpty ? "请重新登录后继续操作" : message,
                actionTitle: "知道了",
                severity: .warning,
                isRetryable: false
            )
        case .server(_, let message):
            return AppErrorPresentation(
                id: id,
                title: "服务异常",
                message: message.isEmpty ? "服务暂时不可用，请稍后重试" : message,
                actionTitle: "重试",
                severity: .error,
                isRetryable: true
            )
        case .cancelled:
            return AppErrorPresentation(
                id: id,
                title: "操作已取消",
                message: error.message,
                actionTitle: "知道了",
                severity: .info,
                isRetryable: false
            )
        case .unknown(let message):
            return AppErrorPresentation(
                id: id,
                title: "出错了",
                message: message.isEmpty ? "发生未知错误，请稍后重试" : message,
                actionTitle: "重试",
                severity: .error,
                isRetryable: true
            )
        }
    }
}
