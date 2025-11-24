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
                .foregroundColor(msg.isMe ? .white : .pink)
                .background(msg.isMe ? Color(hex: 0x5DD100) : Color.gray)
                .cornerRadius(12)

            if !msg.isMe { Spacer() }
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
