import Foundation


protocol ChatWebSocketClientDelegate: AnyObject {
    func webSocketDidConnect(_ client: ChatWebSocketClient)
    func webSocketDidDisconnect(_ client: ChatWebSocketClient, error: Error?)
    func webSocket(_ client: ChatWebSocketClient, didReceive message: ServerMessage)
}


final class ChatWebSocketClient: @unchecked Sendable {
    enum State {
        case disconnected
        case connecting
        case connected
        case authFailed(String)
    }

    private(set) var state: State = .disconnected


    private let url: URL
    private let userId: String
    private let token: String

    private var session: URLSession!
    private var socket: URLSessionWebSocketTask?

    private let reconnectPolicy = WebSocketReconnectPolicy()
    private var heartbeat: WebSocketHeartbeat?

    private var shouldReconnect = true

    weak var delegate: ChatWebSocketClientDelegate?

    init(url: URL, userId: String, token: String) {
        self.url = url
        self.userId = userId
        self.token = token

        let config = URLSessionConfiguration.default
        self.session = URLSession(configuration: config)
    }


    func connect() {
        guard case .disconnected = state else { return }

        shouldReconnect = true
        state = .connecting

        let task = session.webSocketTask(with: url)
        self.socket = task

        self.heartbeat = WebSocketHeartbeat(socket: task)
        self.heartbeat?.onTimeout = { [weak self] in 
            print("Heartbeat timeout, forcing reconnect")
            self?.forceReconnect()
        }


        task.resume()
        listen()
        sendAuth()
    }

    func disconnect() {
        shouldReconnect = false
        heartbeat?.stop()

        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil

        state = .disconnected
        delegate?.webSocketDidDisconnect(self, error: nil)
    }

    func sendChat(to userId: String, text: String) {
        let msg = ClientMessage(
            type: .chat,
            payload: ChatPayload(toUserId: userId, text: text)
        )
        send(msg)
    }

    func sendSeen(messageId: String) {
        let msg = ClientMessage(type: .messageSeen, payload: MessageSeenPayload(messageId: messageId))
        send(msg)
    }

    func sendTyping(to userId: String, isTyping: Bool) {
        let msg = ClientMessage(type: .typing, payload: TypingPayload(toUserId: userId, isTyping: isTyping))
        send(msg)
    }

    private func sendAuth() {
        let msg = ClientMessage(
            type: .auth,
            payload: AuthPayload(userId: userId, token: token)
        )
        send(msg)
    }

    private func send(_ msg: ClientMessage) {
        guard let socket = socket else { return }
        guard let json = WebSocketMessageCoder.encode(msg) else { return }

        socket.send(.string(json)) { [weak self] error in
            if let error = error {
                print("WebSocket send failed: \(error)")
                self?.handleDisconnect(error: error)
            }
        }
    }

    
    private func listen() {
        socket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                self.handleDisconnect(error: error)
            
            case .success(let message):
                self.handleMessage(message)
                self.listen()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleText(text)

        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                handleText(text)
            }

        @unknown default:
            break
        }
    }

    private func handleText(_ text: String) {
        guard let msg = WebSocketMessageCoder.decode(text) else { return }
        switch msg.type {
        case .authOK:
            state = .connected

            reconnectPolicy.reset()
            heartbeat?.start()
            delegate?.webSocketDidConnect(self)

        case .authError:
            if let payload = msg.payload as? AuthErrorPayload {
                state = .authFailed(payload.error)
                shouldReconnect = false
                heartbeat?.stop()
                socket?.cancel()
                delegate?.webSocketDidDisconnect(
                    self,
                    error: NSError(
                        domain: "Auth",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: payload.error]
                    )
                )
            }
            return
        
        default:
            break
        }

        delegate?.webSocket(self, didReceive: msg)
    }

    private func handleDisconnect(error: Error?) {
        guard shouldReconnect else {
            state = .disconnected
            heartbeat?.stop()
            delegate?.webSocketDidDisconnect(self, error: error)
            return
        }

        state = .disconnected
        heartbeat?.stop()
        delegate?.webSocketDidDisconnect(self, error: error)

        scheduleReconnect()
    }

    private func scheduleReconnect() {
        let delay = reconnectPolicy.nextDelay()

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard self.shouldReconnect else { return }
            self.connect()
        }
    }

    private func forceReconnect() {
        socket?.cancel()
        socket = nil

        handleDisconnect(error: NSError(
            domain: "Heartbeat",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Heartbeat timeout"]
        ))
    }
}
