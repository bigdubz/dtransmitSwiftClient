import Foundation
import Combine


@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var messageInput: String = ""
    @Published var isLoadingOlderMessages: Bool = false
    @Published var shouldAutoScrollToBottom: Bool = true
    
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
            timestamp: Date(),
            isSeen: false,
            clientId: tempId
        )
        messages.append(newMsg)
        
        wsClient.sendChat(to: otherUserId, text: text, clientId: tempId)

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
                        timestamp: Date(timeIntervalSince1970: Double(payload.createdAt) / 1000),
                        isSeen: false,
                        clientId: payload.clientId
                    )
                    // Ensure main-thread publish even if invoked off-main
                    Task { @MainActor in
                        self.messages.append(msg)
                    }
                }
            }
            
        case .messageSeen:
            if let payload = message.payload as? MessageIdPayload {
                Task { @MainActor in
                    if let index = messages.firstIndex(where: { $0.clientId == payload.clientId || $0.id == payload.messageId }) {
                        messages[index].isSeen = true
                    }
                }
            }
        
        case .messageDelivered:
            if let payload = message.payload as? MessageIdPayload {
                let msgId = payload.messageId
                Task { @MainActor in
                    if let index = messages.firstIndex(where: { $0.clientId == payload.clientId }) {
                        messages[index].id = msgId
                    }
                }
            }
            
        default:
            break
        }
    }
    
    struct HistoryMessage: Decodable {
        let messageId: String
        let fromUserId: String
        let toUserId: String
        let text: String
        let createdAt: Int
        let delivered: Int
        let seen: Int
    }
    
    func loadHistory(before: Date? = nil) async -> [ChatMessage] {
        guard let token = UserSession.shared.token else { return [] }
        
        
        var components = URLComponents(string: "\(AppConfig.apiBaseURL)/history")!
        components.queryItems = [
            .init(name: "user", value: otherUserId),
            .init(name: "limit", value: "50")
        ]
        if let before {
            let msString = String(Int(before.timeIntervalSince1970 * 1000))
            components.queryItems?.append(.init(name: "before", value: msString))
        }
        
        guard let myURL = components.url else { return [] }
        
        
        var request = URLRequest(url: myURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let history = try JSONDecoder().decode([HistoryMessage].self, from: data)
            
            for row in history where row.seen == 0 {
                markMessageAsSeen(messageId: row.messageId, clientId: row.messageId)
            }
            
            let mapped: [ChatMessage] = history.map { row in
                ChatMessage(
                    id: row.messageId,
                    text: row.text,
                    isMe: (row.fromUserId == myUserId),
                    timestamp: Date(timeIntervalSince1970: TimeInterval(row.createdAt) / 1000),
                    isSeen: row.seen != 0,
                    clientId: row.messageId
                )
            }
            
            
            return mapped.reversed()
            
        } catch {
            print("Failed to load History: \(error)")
            return []
        }
    }
    
    func loadOlderHistory(before: Date) async {
        let sorted = await loadHistory(before: before)
        
        await MainActor.run {
            self.messages.insert(contentsOf: sorted, at: 0)
        }
    }

    func loadInitialHistory() async {
        let sorted = await loadHistory()
        
        await MainActor.run {
            self.messages.removeAll()
            self.messages = sorted
        }
    }

    func markMessageAsSeen(messageId: String, clientId: String) {
        wsClient.sendSeen(messageId: messageId, clientId: clientId)
    }
}
