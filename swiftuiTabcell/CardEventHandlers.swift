import Foundation

enum ImageRowEvent {
    case tapTitle
    case tapImage
    case tapURL
}

struct TextCardCallbacks {
    var onTitleTap: ((Int) -> Void)?
    var onSubtitleTap: ((Int) -> Void)?
}

struct ImageCardEventHandler {
    var onEvent: ((Int, ImageRowEvent) -> Void)?
}

protocol ActionCardEventDelegate: AnyObject {
    func actionCardDidTapTitle(id: Int)
    func actionCardDidTapButton(id: Int)
}

protocol ProfileCardEventDelegate: AnyObject {
    func profileCardDidTapName(id: Int)
    func profileCardDidTapFollow(id: Int)
    func profileCardDidTapMessage(id: Int)
}
