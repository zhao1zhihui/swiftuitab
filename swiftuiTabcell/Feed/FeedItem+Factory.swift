import Foundation

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

    func makeRow() -> FeedRow {
        switch self {
        case .text(let model):
            return .text(TextRowModel(dto: model))
        case .image(let model):
            return .image(ImageRowModel(dto: model))
        case .action(let model):
            return .action(ActionRowModel(dto: model))
        case .profile(let model):
            return .profile(ProfileRowModel(dto: model))
        }
    }
}
