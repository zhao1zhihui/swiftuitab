import Foundation
internal import SwiftUI

final class CardRegistry {
    typealias Builder = (JSONValue) -> AnyCardItem?
    private var builders: [String: Builder] = [:]

    init(textCallbacks: TextCardCallbacks? = nil,
         imageEventHandler: ImageCardEventHandler? = nil,
         actionDelegate: ActionCardEventDelegate? = nil,
         profileDelegate: ProfileCardEventDelegate? = nil) {
        registerDefaults(
            textCallbacks: textCallbacks,
            imageEventHandler: imageEventHandler,
            actionDelegate: actionDelegate,
            profileDelegate: profileDelegate
        )
    }

    func register(_ type: String, builder: @escaping Builder) {
        builders[type] = builder
    }

    func register<T: Decodable>(_ type: String,
                                dto: T.Type,
                                map: @escaping (T) -> AnyCardItem) {
        register(type) { value in
            guard let dto = Self.decode(T.self, from: value) else { return nil }
            return map(dto)
        }
    }

    func makeItem(from raw: FeedRaw) -> AnyCardItem? {
        builders[raw.type]?(raw.data)
    }

    private func registerDefaults(textCallbacks: TextCardCallbacks?,
                                  imageEventHandler: ImageCardEventHandler?,
                                  actionDelegate: ActionCardEventDelegate?,
                                  profileDelegate: ProfileCardEventDelegate?) {
        register("text", dto: TextCard.self) { dto in
            let row = TextRowModel(
                dto: dto,
                onTapTitle: {
                    textCallbacks?.onTitleTap?(dto.id)
                },
                onTapSubtitle: {
                    textCallbacks?.onSubtitleTap?(dto.id)
                }
            )
            return AnyCardItem(id: "text-\(dto.id)", typeKey: "text") {
                TextCardRowView(model: row)
            }
        }
        register("image", dto: ImageCard.self) { dto in
            let row = ImageRowModel(dto: dto, onEvent: { event in
                imageEventHandler?.onEvent?(dto.id, event)
            })
            return AnyCardItem(id: "image-\(dto.id)", typeKey: "image") {
                ImageCardRowView(model: row)
            }
        }
        register("action", dto: ActionCard.self) { dto in
            let row = ActionRowModel(dto: dto, delegate: actionDelegate)
            return AnyCardItem(id: "action-\(dto.id)", typeKey: "action") {
                ActionCardRowView(model: row)
            }
        }
        register("profile", dto: ProfileCard.self) { dto in
            let row = ProfileRowModel(dto: dto, delegate: profileDelegate)
            return AnyCardItem(id: "profile-\(dto.id)", typeKey: "profile") {
                ProfileCardRowView(model: row)
            }
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from value: JSONValue) -> T? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
