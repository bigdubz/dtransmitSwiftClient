import Foundation

// Server -> Client message types

enum ServerMessageType: String, Decodable {
    case authOK = "AUTH_OK"
    case authError = "AUTH_ERROR"

    case chat = "CHAT_MESSAGE"
    case messageDelivered = "MESSAGE_DELIVERED"
    case messageSeen = "MESSAGE_SEEN"

    case error = "ERROR"

    case userOnline = "USER_ONLINE"
    case userOffline = "USER_OFFLINE"
}

struct ServerMessage: Decodable {
    let type: ServerMessageType
    let payload: DecodablePayload

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(ServerMessageType.self, forKey: .type)

        switch type {
            case .authOK:
                payload = try container.decode(AuthOKPayload.self, forKey: .payload)
            case .authError:
                payload = try container.decode(AuthErrorPayload.self, forKey: .payload)
            case .chat:
                payload = try container.decode(ChatMessagePayload.self, forKey: .payload)
            case .messageDelivered, .messageSeen:
                payload = try container.decode(MessageIdPayload.self, forKey: .payload)
            case .error:
                payload = try container.decode(ServerErrorPayload.self, forKey: .payload)
            case .userOnline:
                payload = try container.decode(UserOnlinePayload.self, forKey: .payload)
            case .userOffline:
                payload = try container.decode(UserOfflinePayload.self, forKey: .payload)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }
}

protocol DecodablePayload: Decodable { }


// Payloads

struct AuthOKPayload: DecodablePayload {
    let userId: String
}

struct AuthErrorPayload: DecodablePayload {
    let error: String
}

struct ChatMessagePayload: DecodablePayload {
    let fromUserId: String
    let text: String
    let messageId: String
    let createdAt: TimeInterval
    let clientId: String
}

struct MessageIdPayload: DecodablePayload {
    let messageId: String
    let clientId: String
}

struct ServerErrorPayload: DecodablePayload {
    let error: String
}

struct UserOnlinePayload: DecodablePayload {
    let userId: String
}

struct UserOfflinePayload: DecodablePayload {
    let userId: String
    let lastSeen: TimeInterval
}
