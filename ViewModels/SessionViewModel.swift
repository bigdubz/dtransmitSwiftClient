import Foundation
import Combine


@MainActor
final class SessionViewModel: ObservableObject {


    @Published var userIdInput: String = ""
    @Published var passwordInput: String = ""
    @Published var isLoading: Bool = false
    @Published var loginError: String?
    @Published private(set) var isLoggedIn: Bool = false


    var wsClient: ChatWebSocketClient?
    private var cancellables = Set<AnyCancellable>()

    var activeChatVM: ChatViewModel?
    var webSocketClient: ChatWebSocketClient? { wsClient }


    init() {
        if UserSession.shared.isLoggedIn,
            let userId = UserSession.shared.userId,
            let token = UserSession.shared.token {
                self.isLoggedIn = true
                startWebSocket(userId: userId, token: token)
        }
    }


    func login() async {
        isLoading = true
        loginError = nil

        do {
            let result = try await AuthAPI.login(userId: userIdInput, password: passwordInput)
            UserSession.shared.configure(userId: result.userId, token: result.token)

            isLoggedIn = true

            startWebSocket(userId: result.userId, token: result.token)
        } catch {
            loginError = error.localizedDescription
            isLoggedIn = false
        }

        isLoading = false
    }

    func logout() {
        wsClient?.disconnect()
        wsClient = nil

        UserSession.shared.clear()
        isLoggedIn = false

        userIdInput = ""
        passwordInput = ""
    }

    private func startWebSocket(userId: String, token: String) {
        let wsURL = URL(string: AppConfig.wsBaseURL)!

        let client = ChatWebSocketClient(url: wsURL, userId: userId, token: token)
        client.delegate = self

        self.wsClient = client
        client.connect()
    }
}


extension SessionViewModel: ChatWebSocketClientDelegate {
    func webSocketDidConnect(_ client: ChatWebSocketClient) {
        print("WebSocket Connected")
    }

    func webSocketDidDisconnect(_ client: ChatWebSocketClient, error: Error?) {
        print("WebSocket Disconnected:", error?.localizedDescription ?? "clean")
    }

    func webSocket(_ client: ChatWebSocketClient, didReceive message: ServerMessage) {
        print("WebSocket Message:", message.type.rawValue)
        // Ensure delivery to ChatViewModel on the main actor
        Task { @MainActor in
            self.activeChatVM?.handleWSMessage(message)
        }
    }
}
