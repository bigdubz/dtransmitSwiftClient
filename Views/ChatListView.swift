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
            listContent

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

    private var listContent: some View {
        Group {
            if listVM.isLoading && listVM.conversations.isEmpty {
                ProgressView("Loading conversations...")
            } else if let error = listVM.errorMessage {
                VStack(spacing: 12) {
                    Text("Failed to load conversations")
                        .font(.headline)
                    Text(error)
                        .foregroundColor(.red)
                        .font(.subheadline)
                    Button("Retry") {
                        Task { await listVM.loadConversations() }
                    }
                }
            } else {
                List(listVM.conversations) { convo in
                    NavigationLink {
                        ConversationDestination(listVM: listVM, peerId: convo.id)
                    } label: {
                        ConversationRow(conversation: convo)
                    }
                }
            }
        }
    }

    private var logoutButton: some View {
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
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(timeLabel(for: conversation.lastTimestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if conversation.unreadCount > 0 {
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

    private func timeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct ConversationDestination: View {
    @ObservedObject var listVM: ChatListViewModel
    let peerId: String
    @State private var vm: ChatViewModel?

    var body: some View {
        Group {
            if let vm {
                ChatView(vm: vm)
            } else {
                ProgressView()
                    .task {
                        // Resolve once and store
                        vm = listVM.openConversation(with: peerId)
                        // Optional: log for debugging
                        if let vm {
                            print("Resolved VM for peer:", vm.otherUserId,
                                  "ptr:", Unmanaged.passUnretained(vm).toOpaque())
                        } else {
                            print("Failed to resolve VM for peer:", peerId)
                        }
                    }
            }
        }
    }
}
