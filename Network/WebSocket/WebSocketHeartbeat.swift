import Foundation

final class WebSocketHeartbeat: @unchecked Sendable {
    private weak var socket: URLSessionWebSocketTask?
    private var timer: Timer?

    private let interval: TimeInterval = 15
    private let timeout: TimeInterval = 10

    var onTimeout: (() -> Void)?

    init(socket: URLSessionWebSocketTask?) {
        self.socket = socket
    }

    func start() {
        stop()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sendPing() {
        guard let socket = socket else { return }

        socket.sendPing { [weak self] error in 
            guard let self = self else { return }

            if let error = error {
                print("Ping failed: \(error)")
                self.onTimeout?()
                return
            }
        }
    }
}