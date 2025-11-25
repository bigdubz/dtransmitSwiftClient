import Foundation


@MainActor
final class ChatListViewModel: ObservableObject {

    @Published var conversations: [Conversation] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let sessionVM: SessionViewModel

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

        isLoading = false
    }

    func openConversation(with otherUserId: String) -> ChatViewModel? {
        guard
            let myId = UserSession.shared.userId,
            let ws = sessionVM.wsClient
        else { return nil }

        let vm = ChatViewModel(
            myUserId: myId,
            otherUserId: otherUserId,
            wsClient: ws
        )

        sessionVM.activeChatVM
        return vm
    }
}