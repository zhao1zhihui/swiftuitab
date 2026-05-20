import Foundation

nonisolated enum LocalFeedDataStore {
    static var data: Data {
        Data(json.utf8)
    }

    private static var json: String {
        let items = (1...60).map(makeItemJSON).joined(separator: ",\n")
        return """
        {
          "code": 0,
          "message": "ok",
          "data": {
            "items": [
        \(items)
            ]
          }
        }
        """
    }

    private static func makeItemJSON(id: Int) -> String {
        let page = ((id - 1) / 10) + 1

        switch id % 4 {
        case 1:
            return """
              { "type": "text", "data": { "id": \(id), "title": "Text Card \(id)", "subtitle": "Mock page \(page), used to verify refresh and pagination." } }
            """
        case 2:
            return """
              { "type": "image", "data": { "id": \(id), "title": "Image Card \(id)", "imageUrl": "local-image-\((id % 5) + 1)" } }
            """
        case 3:
            return """
              { "type": "action", "data": { "id": \(id), "title": "Action Card \(id)", "buttonTitle": "Run \(page)" } }
            """
        default:
            return """
              { "type": "profile", "data": { "id": \(id), "name": "User \(id)", "intro": "Mock profile on page \(page).", "followTitle": "Follow", "messageTitle": "Message" } }
            """
        }
    }
}
