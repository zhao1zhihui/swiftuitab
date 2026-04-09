internal import SwiftUI

extension FeedItem {
    static func decode(from decoder: Decoder) throws -> FeedItem {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)
        switch type {
        case .text:
            return .text(try container.decode(TextCard.self, forKey: .data))
        case .image:
            return .image(try container.decode(ImageCard.self, forKey: .data))
        case .action:
            return .action(try container.decode(ActionCard.self, forKey: .data))
        case .profile:
            return .profile(try container.decode(ProfileCard.self, forKey: .data))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode(ItemType.text, forKey: .type)
            try container.encode(value, forKey: .data)
        case .image(let value):
            try container.encode(ItemType.image, forKey: .type)
            try container.encode(value, forKey: .data)
        case .action(let value):
            try container.encode(ItemType.action, forKey: .type)
            try container.encode(value, forKey: .data)
        case .profile(let value):
            try container.encode(ItemType.profile, forKey: .type)
            try container.encode(value, forKey: .data)
        }
    }

    func makeTextCardItem(textCallbacks: TextCardCallbacks? = nil) -> AnyCardItem {
        guard case .text(let model) = self else {
            preconditionFailure("makeTextCardItem can only be used with .text")
        }
        let row = TextRowModel(
            dto: model,
            onTapTitle: {
                textCallbacks?.onTitleTap?(model.id)
            },
            onTapSubtitle: {
                textCallbacks?.onSubtitleTap?(model.id)
            }
        )
        return AnyCardItem(id: "text-\(model.id)", typeKey: "text") {
            TextCardRowView(model: row)
        }
    }

    func makeImageCardItem(imageEventHandler: ImageCardEventHandler? = nil) -> AnyCardItem {
        guard case .image(let model) = self else {
            preconditionFailure("makeImageCardItem can only be used with .image")
        }
        let row = ImageRowModel(dto: model, onEvent: { event in
            imageEventHandler?.onEvent?(model.id, event)
        })
        return AnyCardItem(id: "image-\(model.id)", typeKey: "image") {
            ImageCardRowView(model: row)
        }
    }

    func makeActionCardItem(actionDelegate: ActionCardEventDelegate? = nil) -> AnyCardItem {
        guard case .action(let model) = self else {
            preconditionFailure("makeActionCardItem can only be used with .action")
        }
        let row = ActionRowModel(dto: model, delegate: actionDelegate)
        return AnyCardItem(id: "action-\(model.id)", typeKey: "action") {
            ActionCardRowView(model: row)
        }
    }

    func makeProfileCardItem(profileDelegate: ProfileCardEventDelegate? = nil) -> AnyCardItem {
        guard case .profile(let model) = self else {
            preconditionFailure("makeProfileCardItem can only be used with .profile")
        }
        let row = ProfileRowModel(dto: model, delegate: profileDelegate)
        return AnyCardItem(id: "profile-\(model.id)", typeKey: "profile") {
            ProfileCardRowView(model: row)
        }
    }
}
