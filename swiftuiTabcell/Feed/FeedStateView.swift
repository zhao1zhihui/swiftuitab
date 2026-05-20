 import SwiftUI

struct FeedStateViewStyle {
    let iconName: String
    let iconSize: CGFloat
    let iconColor: Color
    let spacing: CGFloat
    let padding: CGFloat

    static let `default` = FeedStateViewStyle(
        iconName: "tray",
        iconSize: AppSize.stateIcon,
        iconColor: .secondary,
        spacing: AppSpacing.l,
        padding: AppSpacing.xxl
    )
}

struct FeedStateView: View {
    let title: String
    let buttonTitle: String
    let style: FeedStateViewStyle
    let action: () -> Void

    var body: some View {
        VStack(spacing: style.spacing) {
            Image(systemName: style.iconName)
                .font(.system(size: style.iconSize))
                .foregroundStyle(style.iconColor)

            Text(title)
                .font(AppTypography.stateMessage)
                .foregroundStyle(AppColor.secondaryText)
                .multilineTextAlignment(.center)

            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(style.padding)
    }
}
