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
                        model.onTapTitle?()
                    }

                if let subtitle = model.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            model.onTapSubtitle?()
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
                        model.onEvent?(.tapTitle)
                    }

                imageContent
                    .onTapGesture {
                        model.onEvent?(.tapImage)
                    }

                Text(model.imageUrl)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .onTapGesture {
                        model.onEvent?(.tapURL)
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
                        model.delegate?.actionCardDidTapTitle(id: model.id)
                    }

                Button(model.buttonTitle) {
                    model.delegate?.actionCardDidTapButton(id: model.id)
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
                        model.delegate?.profileCardDidTapName(id: model.id)
                    }

                Text(model.intro)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button(model.followTitle) {
                        model.delegate?.profileCardDidTapFollow(id: model.id)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(model.messageTitle) {
                        model.delegate?.profileCardDidTapMessage(id: model.id)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
