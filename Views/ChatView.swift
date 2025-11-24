import SwiftUI


struct ChatView: View {
    @ObservedObject var vm: ChatViewModel

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.messages) { oldValue, newValue in
                    if let last = newValue.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
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
        .task {
            await vm.loadInitialHistory()
        }
    }

    @ViewBuilder
    private func messageBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.isMe { Spacer() }

            Text(msg.text)
                .padding(10)
                .foregroundColor(msg.isMe ? .white : .black)
                .background(msg.isMe ? Color.blue : Color.gray.opacity(0.2))
                .cornerRadius(12)

            if !msg.isMe { Spacer() }
        }
    }
}
