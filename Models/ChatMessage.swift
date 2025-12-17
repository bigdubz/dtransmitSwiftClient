import Foundation


typealias ChatReaction = [String: String]

struct ChatMessage: Identifiable, Equatable {
    var id: String
    let text: String
    let isMe: Bool
    let timestamp: Date
    var isSeen: Bool
    let replyingTo: String?
    var reactions: ChatReaction?
}
