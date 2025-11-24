import Foundation
import Combine


@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var messageInput: String = ""

    let myUserId: String
    let otherUserId: String

    private let wsClient: ChatWebSocketClient

    init(myUserId: String, otherUserId: String, wsClient: ChatWebSocketClient) {
        self.myUserId = myUserId
        self.otherUserId = otherUserId
        self.wsClient = wsClient
    }

    func sendMessage() {
        let text = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let tempId = UUID().uuidString
        let newMsg = ChatMessage(
            id: tempId,
            text: text,
            isMe: true,
            timestamp: Date()
        )
        messages.append(newMsg)

        wsClient.sendChat(to: otherUserId, text: text)

        messageInput = ""
    }

    func handleWSMessage(_ message: ServerMessage) {
        switch message.type {
        case .chat:
            if let payload = message.payload as? ChatMessagePayload {
                if payload.fromUserId == otherUserId {
                    let msg = ChatMessage(
                        id: payload.messageId,
                        text: payload.text,
                        isMe: false,
                        timestamp: Date(timeIntervalSince1970: Double(payload.createdAt) / 1000)
                    )
                    messages.append(msg)
                }
            }

        default:
            break
        }
    }
}
