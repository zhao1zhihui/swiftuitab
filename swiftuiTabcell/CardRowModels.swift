import Foundation

struct TextRowModel {
    let id: Int
    let title: String
    let subtitle: String?

    init(dto: TextCard) {
        self.id = dto.id
        self.title = dto.title
        self.subtitle = dto.subtitle
    }
}

struct ImageRowModel {
    let id: Int
    let title: String
    let imageUrl: String

    init(dto: ImageCard) {
        self.id = dto.id
        self.title = dto.title
        self.imageUrl = dto.imageUrl
    }
}

struct ActionRowModel {
    let id: Int
    let title: String
    let buttonTitle: String

    init(dto: ActionCard) {
        self.id = dto.id
        self.title = dto.title
        self.buttonTitle = dto.buttonTitle
    }
}

struct ProfileRowModel {
    let id: Int
    let name: String
    let intro: String
    let followTitle: String
    let messageTitle: String

    init(dto: ProfileCard) {
        self.id = dto.id
        self.name = dto.name
        self.intro = dto.intro
        self.followTitle = dto.followTitle
        self.messageTitle = dto.messageTitle
    }
}

enum FeedRow: Identifiable {
    case text(TextRowModel)
    case image(ImageRowModel)
    case action(ActionRowModel)
    case profile(ProfileRowModel)

    var id: String {
        switch self {
        case .text(let model):
            return "text-\(model.id)"
        case .image(let model):
            return "image-\(model.id)"
        case .action(let model):
            return "action-\(model.id)"
        case .profile(let model):
            return "profile-\(model.id)"
        }
    }
}
