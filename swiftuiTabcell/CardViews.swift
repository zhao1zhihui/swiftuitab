internal import SwiftUI

private struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
    }
}

struct TextCardRowView: View {
    let model: TextRowModel
    let onAction: (FeedAction) -> Void

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.title)
                    .font(.headline)
                    .onTapGesture {
                        onAction(.tapTextTitle(id: model.id))
                    }

                if let subtitle = model.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            onAction(.tapTextSubtitle(id: model.id))
                        }
                }
            }
        }
    }
}

struct ImageCardRowView: View {
    let model: ImageRowModel
    let onAction: (FeedAction) -> Void

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.title)
                    .font(.headline)
                    .onTapGesture {
                        onAction(.tapImageTitle(id: model.id))
                    }

                imageContent
                    .onTapGesture {
                        onAction(.tapImage(id: model.id))
                    }

                Text(model.imageUrl)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .onTapGesture {
                        onAction(.tapImageURL(id: model.id))
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
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            placeholderView
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var placeholderView: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemGray5))
            Image(systemName: "photo")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
        }
    }
}

struct ActionCardRowView: View {
    let model: ActionRowModel
    let onAction: (FeedAction) -> Void

    var body: some View {
        CardContainer {
            HStack(spacing: 16) {
                Text(model.title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        onAction(.tapActionTitle(id: model.id))
                    }

                Button(model.buttonTitle) {
                    onAction(.tapActionButton(id: model.id))
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct ProfileCardRowView: View {
    let model: ProfileRowModel
    let onAction: (FeedAction) -> Void

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.name)
                    .font(.headline)
                    .onTapGesture {
                        onAction(.tapProfileName(id: model.id))
                    }

                Text(model.intro)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button(model.followTitle) {
                        onAction(.tapProfileFollow(id: model.id))
                    }
                    .buttonStyle(.borderedProminent)

                    Button(model.messageTitle) {
                        onAction(.tapProfileMessage(id: model.id))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

struct FeedRowView: View {
    let row: FeedRow
    let onAction: (FeedAction) -> Void

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch row {
        case .text(let model):
            TextCardRowView(model: model, onAction: onAction)
        case .image(let model):
            ImageCardRowView(model: model, onAction: onAction)
        case .action(let model):
            ActionCardRowView(model: model, onAction: onAction)
        case .profile(let model):
            ProfileCardRowView(model: model, onAction: onAction)
        }
    }
}
