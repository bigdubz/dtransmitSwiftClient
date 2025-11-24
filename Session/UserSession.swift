import Foundation
import Combine


final class UserSession: ObservableObject {
    static let shared = UserSession()

    @Published private(set) var userId: String?
    @Published private(set) var token: String?

    private init() {
        loadFromKeychain()
    }

    func configure(userId: String, token: String) {
        self.userId = userId
        self.token = token

        KeychainStorage.save(key: "session_userId", value: userId)
        KeychainStorage.save(key: "session_token", value: token)
    }

    func clear() {
        self.userId = nil
        self.token = nil

        KeychainStorage.delete(key: "session_userId")
        KeychainStorage.delete(key: "session_token")
    }

    private func loadFromKeychain() {
        let storedUserId = KeychainStorage.load(key: "session_userId")
        let storedToken = KeychainStorage.load(key: "session_token")

        if let storedUserId = storedUserId,
            let storedToken = storedToken {
                self.userId = storedUserId
                self.token = storedToken
        }
    }

    var isLoggedIn: Bool {
        userId != nil && token != nil
    }
}
