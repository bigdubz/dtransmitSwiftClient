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
                    // Ensure main-thread publish even if invoked off-main
                    Task { @MainActor in
                        self.messages.append(msg)
                    }
                }
            }

        default:
            break
        }
    }

    func loadInitialHistory() async {
        guard let token = UserSession.shared.token else { return }
        
        // MARK: CHANGE HERE
        guard let myURL = URL(string: "https://lonely-variety-stolen-cherry.trycloudflare.com/history?user=\(otherUserId)&limit=50") else {
            return
        }

        var request = URLRequest(url: myURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            struct HistoryMessage: Decodable {
                let messageId: String
                let fromUserId: String
                let toUserId: String
                let text: String
                let createdAt: Int
                let delivered: Int
                let seen: Int
            }

            let history = try JSONDecoder().decode([HistoryMessage].self, from: data)

            let mapped: [ChatMessage] = history.map { row in 
                ChatMessage(
                    id: row.messageId,
                    text: row.text,
                    isMe: (row.fromUserId == myUserId),
                    timestamp: Date(timeIntervalSince1970: TimeInterval(row.createdAt) / 1000)
                )
            }

            let sorted = mapped.sorted { $0.timestamp < $1.timestamp }
            // Ensure main-thread publish
            await MainActor.run {
                self.messages = sorted
            }
        } catch {
            print("Failed to load history:", error)
        }
    }
}
