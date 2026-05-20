import SwiftUI

/// 设计系统第一层 token。
/// 先把间距、圆角、字号命名固定下来，后续业务页面不要随手写 magic number。
enum AppSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

enum AppRadius {
    static let card: CGFloat = 8
    static let control: CGFloat = 8
    static let media: CGFloat = 8
}

enum AppSize {
    static let feedImageHeight: CGFloat = 180
    static let stateIcon: CGFloat = 32
}

enum AppTypography {
    static let pageTitle: Font = .largeTitle
    static let cardTitle: Font = .headline
    static let cardBody: Font = .subheadline
    static let caption: Font = .footnote
    static let stateMessage: Font = .body
}

enum AppColor {
    static let cardBackground = Color(.secondarySystemBackground)
    static let subtleBackground = Color.gray.opacity(0.12)
    static let placeholderBackground = Color(.systemGray5)
    static let secondaryText = Color.secondary
}
