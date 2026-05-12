import Foundation

struct TextRowModel {
    enum Event {
        case tapTitle
        case tapSubtitle
    }

    typealias EventHandler = (Event, TextRowModel) -> Void

    let id: Int
    let title: String
    let subtitle: String?
    let onEvent: EventHandler?

    init(id: Int,
         title: String,
         subtitle: String?,
         onEvent: EventHandler? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.onEvent = onEvent
    }

    init(dto: TextCard, onEvent: EventHandler? = nil) {
        self.init(id: dto.id,
                  title: dto.title,
                  subtitle: dto.subtitle,
                  onEvent: onEvent)
    }

    func binding(onEvent: EventHandler?) -> TextRowModel {
        TextRowModel(id: id, title: title, subtitle: subtitle, onEvent: onEvent)
    }

    func trigger(_ event: Event) {
        onEvent?(event, self)
    }
}

struct ImageRowModel {
    enum Event {
        case tapTitle
        case tapImage
        case tapURL
    }

    typealias EventHandler = (Event, ImageRowModel) -> Void

    let id: Int
    let title: String
    let imageUrl: String
    let onEvent: EventHandler?

    init(id: Int,
         title: String,
         imageUrl: String,
         onEvent: EventHandler? = nil) {
        self.id = id
        self.title = title
        self.imageUrl = imageUrl
        self.onEvent = onEvent
    }

    init(dto: ImageCard, onEvent: EventHandler? = nil) {
        self.init(id: dto.id,
                  title: dto.title,
                  imageUrl: dto.imageUrl,
                  onEvent: onEvent)
    }

    func binding(onEvent: EventHandler?) -> ImageRowModel {
        ImageRowModel(id: id, title: title, imageUrl: imageUrl, onEvent: onEvent)
    }

    func trigger(_ event: Event) {
        onEvent?(event, self)
    }
}

struct ActionRowModel {
    enum Event {
        case tapTitle
        case tapButton
    }

    typealias EventHandler = (Event, ActionRowModel) -> Void

    let id: Int
    let title: String
    let buttonTitle: String
    let onEvent: EventHandler?

    init(id: Int,
         title: String,
         buttonTitle: String,
         onEvent: EventHandler? = nil) {
        self.id = id
        self.title = title
        self.buttonTitle = buttonTitle
        self.onEvent = onEvent
    }

    init(dto: ActionCard, onEvent: EventHandler? = nil) {
        self.init(id: dto.id,
                  title: dto.title,
                  buttonTitle: dto.buttonTitle,
                  onEvent: onEvent)
    }

    func binding(onEvent: EventHandler?) -> ActionRowModel {
        ActionRowModel(id: id, title: title, buttonTitle: buttonTitle, onEvent: onEvent)
    }

    func trigger(_ event: Event) {
        onEvent?(event, self)
    }
}

struct ProfileRowModel {
    enum Event {
        case tapName
        case tapFollow
        case tapMessage
    }

    typealias EventHandler = (Event, ProfileRowModel) -> Void

    let id: Int
    let name: String
    let intro: String
    let followTitle: String
    let messageTitle: String
    let onEvent: EventHandler?

    init(id: Int,
         name: String,
         intro: String,
         followTitle: String,
         messageTitle: String,
         onEvent: EventHandler? = nil) {
        self.id = id
        self.name = name
        self.intro = intro
        self.followTitle = followTitle
        self.messageTitle = messageTitle
        self.onEvent = onEvent
    }

    init(dto: ProfileCard, onEvent: EventHandler? = nil) {
        self.init(id: dto.id,
                  name: dto.name,
                  intro: dto.intro,
                  followTitle: dto.followTitle,
                  messageTitle: dto.messageTitle,
                  onEvent: onEvent)
    }

    func binding(onEvent: EventHandler?) -> ProfileRowModel {
        ProfileRowModel(id: id,
                        name: name,
                        intro: intro,
                        followTitle: followTitle,
                        messageTitle: messageTitle,
                        onEvent: onEvent)
    }

    func trigger(_ event: Event) {
        onEvent?(event, self)
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
