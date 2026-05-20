import Foundation

/// 时间能力协议。
/// 只要业务里出现防抖、延迟、重试、分页 loading 最短展示时间，都应该依赖这个协议，避免测试里真的等待。
nonisolated protocol AppClock: Sendable {
    var now: Date { get }
    func sleep(for seconds: TimeInterval) async throws
}

nonisolated struct SystemAppClock: AppClock {
    var now: Date {
        Date()
    }

    func sleep(for seconds: TimeInterval) async throws {
        guard seconds.isFinite, seconds > 0 else {
            return
        }

        try await Task.sleep(nanoseconds: UInt64((seconds * 1_000_000_000).rounded()))
    }
}

/// UUID 生成协议。
/// 登录 token、埋点 traceId、列表本地 id 等随机值从这里注入，单测就能稳定断言结果。
nonisolated protocol UUIDGenerating: Sendable {
    func makeUUID() -> UUID
}

nonisolated struct SystemUUIDGenerator: UUIDGenerating {
    func makeUUID() -> UUID {
        UUID()
    }
}
