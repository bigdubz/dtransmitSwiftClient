import Foundation

// Server -> Client message types

enum ServerMessageType: String, Decodable {
    case authOK = "AUTH_OK"
    case authError = "AUTH_ERROR"

    case chat = "CHAT_MESSAGE"
    case messageDelivered = "MESSAGE_DELIVERED"
    case messageSeen = "MESSAGE_SEEN"
    case addReaction = "ADD_REACTION"
    case removeReaction = "REMOVE_REACTION"

    case error = "ERROR"

    case userOnline = "USER_ONLINE"
    case userOffline = "USER_OFFLINE"
    
    case userTyping = "USER_TYPING"
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
            case .messageDelivered:
                payload = try container.decode(MessageDeliveredPayload.self, forKey: .payload)
            case .messageSeen:
                payload = try container.decode(ServerMessageSeenPayload.self, forKey: .payload)
            case .addReaction:
                payload = try container.decode(ServerAddReactionPayload.self, forKey: .payload)
            case .removeReaction:
                payload = try container.decode(ServerRemoveReactionPayload.self, forKey: .payload)
            case .userTyping:
                payload = try container.decode(ServerTypingPayload.self, forKey: .payload)
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
    let isOnline: Bool
    let replyingTo: String?
}

struct MessageDeliveredPayload: DecodablePayload {
    let messageId: String
    let clientId: String
}

struct ServerMessageSeenPayload: DecodablePayload {
    let messageId: String
}

struct ServerAddReactionPayload: DecodablePayload {
    let messageId: String
    let userId: String
    let reaction: String
}

struct ServerRemoveReactionPayload: DecodablePayload {
    let messageId: String
    let userId: String
}

struct ServerTypingPayload: DecodablePayload {
    let fromUserId: String
    let isTyping: Bool
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
