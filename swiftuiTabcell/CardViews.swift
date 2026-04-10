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

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.title)
                    .font(.headline)
                    .onTapGesture {
                        model.trigger(.tapTitle)
                    }

                if let subtitle = model.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
            VStack(alignment: .leading, spacing: 12) {
                Text(model.title)
                    .font(.headline)
                    .onTapGesture {
                        model.trigger(.tapTitle)
                    }

                imageContent
                    .onTapGesture {
                        model.trigger(.tapImage)
                    }

                Text(model.imageUrl)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

    var body: some View {
        CardContainer {
            HStack(spacing: 16) {
                Text(model.title)
                    .font(.headline)
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
            VStack(alignment: .leading, spacing: 12) {
                Text(model.name)
                    .font(.headline)
                    .onTapGesture {
                        model.trigger(.tapName)
                    }

                Text(model.intro)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
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
