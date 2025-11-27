import SwiftUI

// MARK: TODO
// TODO:    receive message through websocket when in ChatListView -- done
//          seen/delivered indicators
//          typing indicators
//          try fixing scrolling issue inside ChatView but prob not lmfaooo


struct ChatView: View {
    @ObservedObject var vm: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    var lastSeenMessageId: String? {
        vm.messages
            .filter { $0.isMe }
            .last(where: { $0.isSeen })?.id
    }

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Color.clear
                            .frame(height: 1)
                            .id("TOP_SENTINEL")
                            .onAppear {
                                guard !vm.isLoadingOlderMessages else { return }
                                vm.isLoadingOlderMessages = true
                                vm.shouldAutoScrollToBottom = false

                                Task {
                                    let firstMessage = vm.messages.first
                                    
                                    if let firstMessage {
                                        await vm.loadOlderHistory(before: firstMessage.timestamp)
                                        withAnimation {
                                            proxy.scrollTo(firstMessage.id, anchor: .bottom)
                                        }
                                    }
                                    
                                    vm.isLoadingOlderMessages = false
                                    vm.shouldAutoScrollToBottom = true
                                }
                            }
                        ForEach(vm.messages) { msg in
                            messageBubble(
                                msg,
                                showSeen: msg.id == lastSeenMessageId
                            )
                            .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.messages) { oldValue, newValue in
                    guard vm.shouldAutoScrollToBottom else { return }
                    guard let last = newValue.last else { return }
                    
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                    if !last.isMe {
                        vm.markMessageAsSeen(messageId: last.id, clientId: last.clientId)
                    }
                }
            }
            
            HStack {
                TextField("Send a message...", text: $vm.messageInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Send") {
                    vm.sendMessage()
                }
                .padding(.horizontal)
                .disabled(vm.messageInput.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Chat with \(vm.otherUserId)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward.circle.fill")
                        .font(.system(size: 20))
                }
            }
        }
        .task {
            await vm.loadInitialHistory()
        }
    }

    @ViewBuilder
    private func messageBubble(_ msg: ChatMessage, showSeen: Bool) -> some View {
        HStack {
            if msg.isMe { Spacer() }

            Text(msg.text)
                .padding(10)
                .foregroundColor(msg.isMe ? .white : .pink)
                .background(msg.isMe ? Color(hex: 0x5DD100) : Color.gray)
                .cornerRadius(12)

            if !msg.isMe { Spacer() }
        }
        
        if showSeen {
            Text("Seen")
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.horizontal, msg.isMe ? 0 : 20)
        }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
