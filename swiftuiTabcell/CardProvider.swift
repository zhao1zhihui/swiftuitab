import Foundation

protocol CardProvider {
    func loadItems(page: Int, pageSize: Int) async -> APIResult<PageResult<AnyCardItem>>
}

final class EnumCardProvider: CardProvider {
    private let repository = FeedRepository()
    private let textCallbacks: TextCardCallbacks?
    private let imageEventHandler: ImageCardEventHandler?
    private weak var actionDelegate: ActionCardEventDelegate?
    private weak var profileDelegate: ProfileCardEventDelegate?

    init(textCallbacks: TextCardCallbacks? = nil,
         imageEventHandler: ImageCardEventHandler? = nil,
         actionDelegate: ActionCardEventDelegate? = nil,
         profileDelegate: ProfileCardEventDelegate? = nil) {
        self.textCallbacks = textCallbacks
        self.imageEventHandler = imageEventHandler
        self.actionDelegate = actionDelegate
        self.profileDelegate = profileDelegate
    }

    func loadItems(page: Int, pageSize: Int) async -> APIResult<PageResult<AnyCardItem>> {
        let result = await repository.fetchFeed(page: page, pageSize: pageSize)
        return result.map { pageResult in
            pageResult.mapItems { item in
                switch item {
                case .text:
                    return item.makeTextCardItem(textCallbacks: textCallbacks)
                case .image:
                    return item.makeImageCardItem(imageEventHandler: imageEventHandler)
                case .action:
                    return item.makeActionCardItem(actionDelegate: actionDelegate)
                case .profile:
                    return item.makeProfileCardItem(profileDelegate: profileDelegate)
                }
            }
        }
    }
}

final class RegistryCardProvider: CardProvider {
    private let repository = FeedRepository()
    private let registry: CardRegistry

    init(registry: CardRegistry = CardRegistry()) {
        self.registry = registry
    }

    convenience init(textCallbacks: TextCardCallbacks? = nil,
                     imageEventHandler: ImageCardEventHandler? = nil,
                     actionDelegate: ActionCardEventDelegate? = nil,
                     profileDelegate: ProfileCardEventDelegate? = nil) {
        self.init(
            registry: CardRegistry(
                textCallbacks: textCallbacks,
                imageEventHandler: imageEventHandler,
                actionDelegate: actionDelegate,
                profileDelegate: profileDelegate
            )
        )
    }

    func loadItems(page: Int, pageSize: Int) async -> APIResult<PageResult<AnyCardItem>> {
        let result = await repository.fetchFeedRaw(page: page, pageSize: pageSize)
        return result.map { pageResult in
            let mapped = pageResult.items.compactMap { registry.makeItem(from: $0) }
            return PageResult(items: mapped, page: pageResult.page, pageSize: pageResult.pageSize, hasMore: pageResult.hasMore)
        }
    }
}
