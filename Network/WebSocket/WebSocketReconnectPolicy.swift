import Foundation


final class WebSocketReconnectPolicy {
    private let maxDelay: TimeInterval
    private let baseDelay: TimeInterval
    private var attempt: Int = 0

    init(baseDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 32.0) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    func nextDelay() -> TimeInterval {
        let exp = pow(2.0, Double(attempt))
        var delay = baseDelay * exp

        delay = min(delay, maxDelay)

        let jitter = delay * 0.2
        let randomJitter = Double.random(in: -jitter...jitter)

        attempt += 1
        return max(0.5, delay + randomJitter)
    }

    func reset() {
        attempt = 0
    }
}