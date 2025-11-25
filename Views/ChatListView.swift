import SwiftUI


struct ChatListView: View {
    @ObservedObject var sessionVM: SessionViewModel
    @StateObject private var listVM: ChatListViewModel

    init(sessionVM: SessionViewModel) {
        self.sessionVM = sessionVM
        _listVM = StateObject(wrappedValue: ChatListViewModel(sessionVM: sessionVM))
    }

    var body: some View {
        ZStack {
            Group {
                if listVM.isLoading && listVM.conversations.isEmpty {
                    ProgressView("Loading conversations...")
                } else if let error = listVM.errorMessage {
                    VStack(spacing: 12) {
                        Text("Failed to load conversations")
                            .font(.headline)
                        Text(error)
                            .foregroundColor(.red)
                            .font(.subheadLine)
                        Button("Retry") {
                            Task { await listVM.loadConversations() }
                        }
                    }
                } else {
                    List(listVM.conversations) { convo in 
                        NavigationLink {
                            if let vm = listVM.chatViewModel(for: convo) {
                                ChatView(vm: vm)
                            } else {
                                Text("Unable to open chat")
                            }
                        } label: {
                            ConversationRow(conversation: convo)
                        }
                    }
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    logoutButton
                }
                .padding()
            }
        }
        .navigationTitle("Chats")
        .task {
            await listVM.loadConversations()
        }
    }
}

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(conversation.isOnline ? Color.green : Color.gray)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.id)
                    .font(.headline)

                Text(conversation.lastMessage)
                    .font(.subheadLine)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(timeLabel(for: conversation.lastTimestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if conversation.undreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.caption2)
                        .padding(6)
                        .background(Color.blue.opacity(0.85))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var logoutbutton: some View {
        Button {
            sessionVM.logout()
        } label: {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
                .clipShape(Circle())
                .shadow(radius: 3)
        }
        .accessibilityLabel("Logout")
    }

    private func timeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}