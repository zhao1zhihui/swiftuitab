import Foundation

enum FeedAction {
    case tapTextTitle(id: Int)
    case tapTextSubtitle(id: Int)
    case tapImageTitle(id: Int)
    case tapImage(id: Int)
    case tapImageURL(id: Int)
    case tapActionTitle(id: Int)
    case tapActionButton(id: Int)
    case tapProfileName(id: Int)
    case tapProfileFollow(id: Int)
    case tapProfileMessage(id: Int)
}
