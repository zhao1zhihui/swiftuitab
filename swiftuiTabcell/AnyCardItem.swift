internal import SwiftUI

struct AnyCardItem: Identifiable {
    let id: String
    let typeKey: String
    private let content: () -> AnyView

    init<V: View>(id: String, typeKey: String, @ViewBuilder content: @escaping () -> V) {
        self.id = id
        self.typeKey = typeKey
        self.content = { AnyView(content()) }
    }

    func render() -> AnyView {
        content()
    }
}
