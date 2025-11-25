import Foundation


struct Conversation: Identifiable, Equatable {
    let id: String
    var lastMessage: String
    var lastTimestamp: Date
    var unreadCount: Int
    var isOnline: Bool
}