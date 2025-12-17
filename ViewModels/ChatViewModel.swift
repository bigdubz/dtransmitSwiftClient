import Foundation
import Combine


@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var messageInput: String = ""
    @Published var isLoadingOlderMessages: Bool = false
    @Published var shouldAutoScrollToBottom: Bool = true
    @Published var didInitialScrollToBottom: Bool = false
    @Published var otherUserIsTyping: Bool = false
    @Published var isReplyingTo: ChatMessage? = nil
    @Published var otherUserOnline: Bool = false
    
    private var typingDebounceTimer: Timer?
    private var didSendTypingTrue = false
    
    let myUserId: String
    let otherUserId: String

    private let wsClient: ChatWebSocketClient

    init(myUserId: String, otherUserId: String, wsClient: ChatWebSocketClient, isOnline: Bool) {
        self.myUserId = myUserId
        self.otherUserId = otherUserId
        self.wsClient = wsClient
        self.otherUserOnline = isOnline
    }

    func sendMessage() {
        let text = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        typingDebounceTimer?.invalidate()
        
        Task { @MainActor in
            self.didSendTypingTrue = false
            self.sendIsTyping(toUserId: self.otherUserId, isTyping: false)
            self.isReplyingTo = nil
        }
        
        let tempId = UUID().uuidString
        let newMsg = ChatMessage(
            id: tempId,
            text: text,
            isMe: true,
            timestamp: Date(),
            isSeen: false,
            replyingTo: self.isReplyingTo?.id
        )
        messages.append(newMsg)
        
        wsClient.sendChat(to: otherUserId, text: text, clientId: tempId, replyingTo: isReplyingTo?.id)

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
                        replyingTo: payload.replyingTo
                    )
                    // Ensure main-thread publish even if invoked off-main
                    Task { @MainActor in
                        self.messages.append(msg)
                    }
                }
            }
            
        case .messageSeen:
            if let payload = message.payload as? ServerMessageSeenPayload {
                Task { @MainActor in
                    if let index = messages.firstIndex(where: { $0.id == payload.messageId }) {
                        messages[index].isSeen = true
                    }
                }
            }
        
        case .messageDelivered:
            if let payload = message.payload as? MessageDeliveredPayload {
                Task { @MainActor in
                    if let index = messages.firstIndex(where: { $0.id == payload.clientId }) {
                        messages[index].id = payload.messageId
                    }
                }
            }
            
        case .addReaction:
            if let payload = message.payload as? ServerAddReactionPayload {
                Task { @MainActor in
                    if let index = messages.firstIndex(where: { $0.id == payload.messageId }) {
                        if messages[index].reactions == nil {
                            messages[index].reactions = [:]
                        }
                        messages[index].reactions?[payload.userId] = payload.reaction
                    }
                }
            }
            
        case .removeReaction:
            if let payload = message.payload as? ServerRemoveReactionPayload {
                Task { @MainActor in
                    if let index = messages.firstIndex(where: { $0.id == payload.messageId }) {
                        messages[index].reactions?[payload.userId] = nil
                    }
                }
            }
            
        case .userTyping:
            if let payload = message.payload as? ServerTypingPayload {
                Task { @MainActor in
                    if payload.fromUserId == otherUserId {
                        otherUserIsTyping = payload.isTyping
                    }
                }
            }
        
        case .userOnline:
            if let payload = message.payload as? UserOnlinePayload, payload.userId == otherUserId {
                Task { @MainActor in
                    otherUserOnline = true
                }
            }
            
        case .userOffline:
            if let payload = message.payload as? UserOfflinePayload, payload.userId == otherUserId {
                Task { @MainActor in
                    otherUserOnline = false
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
        let replyingTo: String?
        let reactions: ChatReaction?
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
            
            for row in history where row.seen == 0 && row.fromUserId != myUserId {
                markMessageAsSeen(messageId: row.messageId)
            }
            
            let mapped: [ChatMessage] = history.map { row in
                ChatMessage(
                    id: row.messageId,
                    text: row.text,
                    isMe: (row.fromUserId == myUserId),
                    timestamp: Date(timeIntervalSince1970: TimeInterval(row.createdAt) / 1000),
                    isSeen: row.seen != 0,
                    replyingTo: row.replyingTo,
                    reactions: row.reactions
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
    
    func userStartedTyping() {
        if !didSendTypingTrue {
            sendIsTyping(toUserId: otherUserId, isTyping: true)
            didSendTypingTrue = true
        }
        
        typingDebounceTimer?.invalidate()
        typingDebounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            
            Task { @MainActor in
                self.didSendTypingTrue = false
                self.sendIsTyping(toUserId: self.otherUserId, isTyping: false)
            }
        }
    }

    func markMessageAsSeen(messageId: String) {
        wsClient.sendSeen(messageId: messageId)
    }
    
    func sendIsTyping(toUserId: String, isTyping: Bool) {
        wsClient.sendTyping(to: toUserId, isTyping: isTyping)
    }
    
    func sendReaction(messageId: String, reaction: String) {
        wsClient.sendReaction(to: otherUserId, messageId: messageId, reaction: reaction)
    }
    
    func removeReaction(messageId: String) {
        wsClient.sendRemoveReaction(to: otherUserId, messageId: messageId)
    }
}
