import Foundation


struct ChatMessage: Identifiable, Equatable {
    let id: String
    let text: String
    let isMe: Bool
    let timestamp: Date
}
