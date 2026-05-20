 import SwiftUI

private struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(AppColor.cardBackground)
            )
    }
}

struct TextCardRowView: View {
    let model: TextRowModel

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text(model.title)
                    .font(AppTypography.cardTitle)
                    .onTapGesture {
                        model.trigger(.tapTitle)
                    }

                if let subtitle = model.subtitle {
                    Text(subtitle)
                        .font(AppTypography.cardBody)
                        .foregroundStyle(AppColor.secondaryText)
                        .onTapGesture {
                            model.trigger(.tapSubtitle)
                        }
                }
            }
        }
    }
}

struct ImageCardRowView: View {
    let model: ImageRowModel

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text(model.title)
                    .font(AppTypography.cardTitle)
                    .onTapGesture {
                        model.trigger(.tapTitle)
                    }

                imageContent
                    .onTapGesture {
                        model.trigger(.tapImage)
                    }

                Text(model.imageUrl)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.secondaryText)
                    .lineLimit(2)
                    .onTapGesture {
                        model.trigger(.tapURL)
                    }
            }
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let url = URL(string: model.imageUrl),
           let scheme = url.scheme,
           !scheme.isEmpty,
           !model.imageUrl.isEmpty {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholderView
            }
            .frame(height: AppSize.feedImageHeight)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.media, style: .continuous))
        } else {
            placeholderView
                .frame(height: AppSize.feedImageHeight)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.media, style: .continuous))
        }
    }

    private var placeholderView: some View {
        ZStack {
            Rectangle()
                .fill(AppColor.placeholderBackground)
            Image(systemName: "photo")
                .font(.system(size: 28))
                .foregroundStyle(AppColor.secondaryText)
        }
    }
}

struct ActionCardRowView: View {
    let model: ActionRowModel

    var body: some View {
        CardContainer {
            HStack(spacing: AppSpacing.l) {
                Text(model.title)
                    .font(AppTypography.cardTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        model.trigger(.tapTitle)
                    }

                Button(model.buttonTitle) {
                    model.trigger(.tapButton)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct ProfileCardRowView: View {
    let model: ProfileRowModel

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text(model.name)
                    .font(AppTypography.cardTitle)
                    .onTapGesture {
                        model.trigger(.tapName)
                    }

                Text(model.intro)
                    .font(AppTypography.cardBody)
                    .foregroundStyle(AppColor.secondaryText)

                HStack(spacing: AppSpacing.m) {
                    Button(model.followTitle) {
                        model.trigger(.tapFollow)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(model.messageTitle) {
                        model.trigger(.tapMessage)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

struct FeedRowView: View {
    let row: FeedRow

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch row {
        case .text(let model):
            TextCardRowView(model: model)
        case .image(let model):
            ImageCardRowView(model: model)
        case .action(let model):
            ActionCardRowView(model: model)
        case .profile(let model):
            ProfileCardRowView(model: model)
        }
    }
}
