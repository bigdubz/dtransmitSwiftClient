import Foundation
import Combine


@MainActor
final class ChatListViewModel: ObservableObject {

    @Published var conversations: [Conversation] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let sessionVM: SessionViewModel

    // Cache a single ChatViewModel per conversation/user
    private var chatVMs: [String: ChatViewModel] = [:]

    init(sessionVM: SessionViewModel) {
        self.sessionVM = sessionVM
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
        print("sanity check: \(conversations)")
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
        print("my user id: \(myId), other user id: \(otherUserId)")
        chatVMs[otherUserId] = vm
        sessionVM.activeChatVM = vm
        return vm
    }
}
