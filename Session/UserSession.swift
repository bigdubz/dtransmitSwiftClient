import Foundation


final class UserSession: ObservableObject {
    static let shared = UserSession()

    @Published private(set) var userId: String?
    @Published private(set) var token: String?

    private init() { }

    func configure(userId: String, token: String) {
        self.userId = userId
        self.token = token
    }

    func clear() {
        self.userId = nil
        self.token = nil
    }

    var isLoggedIn: Bool {
        userId != nil && token != nil
    }
}