import Foundation


struct ConversationDTO: Decodable {
    let peerId: String
    let lastMessage: String
    let lastTimestamp: Int
    let unreadCount: Int
    let isOnline: Bool
}

enum ConversationsAPI {
    private static let baseURL = AuthAPI.baseURL

    static func fetchConversations(token: String) async throws -> [Conversation] {
        let url = baseURL.appendingPathComponent("conversations")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse {
            guard (200..<300).contains(http.statusCode) else {
                throw NSError(
                    domain: "ConversationsAPI",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
                )
            }
        }

        let decoder = JSONDecoder()
        let dtos = try decoder.decode([ConversationDTO].self, from: data)
        
        return dtos.map { dto in
            Conversation(
                id: dto.peerId,
                lastMessage: dto.lastMessage,
                lastTimestamp: Date(timeIntervalSince1970: TimeInterval(dto.lastTimestamp) / 1000),
                unreadCount: dto.unreadCount,
                isOnline: dto.isOnline
            )
        }
        .sorted { $0.lastTimestamp > $1.lastTimestamp }
    }
}
