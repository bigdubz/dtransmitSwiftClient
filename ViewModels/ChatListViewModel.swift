import Foundation
import Combine


@MainActor
final class ChatListViewModel: ObservableObject {

    @Published var conversations: [Conversation] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let sessionVM: SessionViewModel

    private var chatVMs: [String: ChatViewModel] = [:]

    init(sessionVM: SessionViewModel) {
        self.sessionVM = sessionVM
        self.sessionVM.chatListVM = self
    }

    func loadConversations() async {
        guard let token = UserSession.shared.token else {
            errorMessage = "No token"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let convs = try await ConversationsAPI.fetchConversations(token: token)
            conversations = convs
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func openConversation(with otherUserId: String) -> ChatViewModel? {
        guard
            let myId = UserSession.shared.userId,
            let ws = sessionVM.wsClient
        else { return nil }

        if let existing = chatVMs[otherUserId] {
            sessionVM.activeChatVM = existing
            return existing
        }

        let vm = ChatViewModel(
            myUserId: myId,
            otherUserId: otherUserId,
            wsClient: ws
        )
        chatVMs[otherUserId] = vm
        sessionVM.activeChatVM = vm
        return vm
    }
    
    func handleWSMessage(_ message: ServerMessage) {
        switch message.type {
        case .chat:
            if let payload = message.payload as? ChatMessagePayload {
                if let index = conversations.firstIndex(where: { $0.id == payload.fromUserId}) {
                    conversations[index].unreadCount += 1
                    conversations[index].lastMessage = payload.text
                    conversations[index].lastTimestamp = Date(timeIntervalSince1970: payload.createdAt / 1000)
                }
            }
            
        case .userOnline:
            if let payload = message.payload as? UserOnlinePayload {
                if let index = conversations.firstIndex(where: { $0.id == payload.userId }) {
                    conversations[index].isOnline = true
                }
            }
            
        case .userOffline:
            if let payload = message.payload as? UserOfflinePayload {
                if let index = conversations.firstIndex(where: { $0.id == payload.userId }) {
                    conversations[index].isOnline = false
                }
            }
            
        default:
            break
            
        }
    }
}
