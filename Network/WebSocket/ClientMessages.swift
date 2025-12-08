import Foundation

// Client -> Server message types

enum ClientMessageType: String, Encodable {
    case auth = "AUTH"
    case chat = "CHAT_MESSAGE"
    case messageSeen = "MESSAGE_SEEN"
    case typing = "USER_TYPING"
    case addReaction = "ADD_REACTION"
    case removeReaction = "REMOVE_REACTION"
}

struct ClientMessage: Encodable {
    let type: ClientMessageType
    let payload: EncodablePayload

    init(type: ClientMessageType, payload: EncodablePayload) {
        self.type = type
        self.payload = payload
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try payload.encode(to: container.superEncoder(forKey: .payload))
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }
}


// Client payloads

protocol EncodablePayload: Encodable { }

struct AuthPayload: EncodablePayload {
    let userId: String
    let token: String
}

struct ChatPayload: EncodablePayload {
    let toUserId: String
    let text: String
    let clientId: String
    let replyingTo: String?
}

struct MessageSeenPayload: EncodablePayload {
    let messageId: String
}

struct TypingPayload: EncodablePayload {
    let toUserId: String
    let isTyping: Bool
}

struct AddReactionPayload: EncodablePayload {
    let messageId: String
    let reaction: String
    let toUserId: String
}

struct RemoveReactionPayload: EncodablePayload {
    let messageId: String
    let toUserId: String
}
