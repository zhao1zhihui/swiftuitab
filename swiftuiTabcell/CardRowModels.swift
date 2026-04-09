import Foundation

final class TextRowModel {
    let id: Int
    let title: String
    let subtitle: String?
    let onTapTitle: (() -> Void)?
    let onTapSubtitle: (() -> Void)?

    init(dto: TextCard,
         onTapTitle: (() -> Void)? = nil,
         onTapSubtitle: (() -> Void)? = nil) {
        self.id = dto.id
        self.title = dto.title
        self.subtitle = dto.subtitle
        self.onTapTitle = onTapTitle
        self.onTapSubtitle = onTapSubtitle
    }
}

final class ImageRowModel {
    let id: Int
    let title: String
    let imageUrl: String
    let onEvent: ((ImageRowEvent) -> Void)?

    init(dto: ImageCard, onEvent: ((ImageRowEvent) -> Void)? = nil) {
        self.id = dto.id
        self.title = dto.title
        self.imageUrl = dto.imageUrl
        self.onEvent = onEvent
    }
}

final class ActionRowModel {
    let id: Int
    let title: String
    let buttonTitle: String
    weak var delegate: ActionCardEventDelegate?

    init(dto: ActionCard, delegate: ActionCardEventDelegate? = nil) {
        self.id = dto.id
        self.title = dto.title
        self.buttonTitle = dto.buttonTitle
        self.delegate = delegate
    }
}

final class ProfileRowModel {
    let id: Int
    let name: String
    let intro: String
    let followTitle: String
    let messageTitle: String
    weak var delegate: ProfileCardEventDelegate?

    init(dto: ProfileCard, delegate: ProfileCardEventDelegate? = nil) {
        self.id = dto.id
        self.name = dto.name
        self.intro = dto.intro
        self.followTitle = dto.followTitle
        self.messageTitle = dto.messageTitle
        self.delegate = delegate
    }
}
