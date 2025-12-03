import SwiftUI


struct ChatView: View {
    @ObservedObject var vm: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Keyboard focus
    @FocusState private var inputFocused: Bool
    
    // Convenience: ID of the last seen message
    var lastSeenMessageId: String? {
        vm.messages
            .filter { $0.isMe }
            .last(where: { $0.isSeen })?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            
            messagesSection
            
            if vm.otherUserIsTyping {
                typingIndicatorSection
            }
            
            inputBarSection
        }
        .background(AppConfig.globalBackgroundColor)
        
        // GLOBAL TAP TO DISMISS KEYBOARD
        .onTapGesture {
            inputFocused = false
        }
        
        .navigationTitle("Chat with \(vm.otherUserId)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                closeButton
            }
        }
        .task {
            await vm.loadInitialHistory()
        }
    }
    
    private var messagesSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {

                    topHistoryLoader(proxy: proxy)
                    
                    ForEach(vm.messages.indices, id: \.self) { index in
                        let msg = vm.messages[index]
                        let prev = index > 0 ? vm.messages[index - 1] : nil
                        
                        let isSenderSwitch = prev == nil || msg.isMe != prev!.isMe
                        
                        messageBubble(
                            msg,
                            showSeen: msg.id == lastSeenMessageId,
                            showTimestamp: shouldShowTimestamp(current: msg, previous: prev)
                        )
                        .padding(.top, isSenderSwitch ? 12 : 0)
                        .id(msg.id)
                    }
                    
                    bottomSentinel
                }
                .padding()
            }
            
            // Auto-scroll on new messages
            .onChange(of: vm.messages) { oldValue, newValue in
                guard vm.shouldAutoScrollToBottom else { return }
                guard let last = newValue.last else { return }
                
                withAnimation {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }

                if !last.isMe {
                    vm.markMessageAsSeen(messageId: last.id)
                }
            }
            
            // Auto-scroll when "seen" changes
            .onChange(of: lastSeenMessageId) { _, newValue in
                guard let id = newValue else { return }
                withAnimation {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
            
            // Scroll while typing
            .onChange(of: vm.otherUserIsTyping) { wasTyping, isTyping in
                if isTyping {
                    withAnimation {
                        proxy.scrollTo("BOTTOM_SENTINEL", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func topHistoryLoader(proxy: ScrollViewProxy) -> some View {
        Color.clear
            .frame(height: 1)
            .id("TOP_SENTINEL")
            .onAppear {
                guard !vm.isLoadingOlderMessages else { return }
                vm.isLoadingOlderMessages = true
                vm.shouldAutoScrollToBottom = false

                Task {
                    if let firstMessage = vm.messages.first {
                        await vm.loadOlderHistory(before: firstMessage.timestamp)
                        withAnimation {
                            proxy.scrollTo(firstMessage.id, anchor: .bottom)
                        }
                    }
                    
                    vm.isLoadingOlderMessages = false
                    vm.shouldAutoScrollToBottom = true
                }
            }
    }
    
    private var bottomSentinel: some View {
        Color.clear
            .frame(height: 1)
            .id("BOTTOM_SENTINEL")
    }
    
    private func shouldShowTimestamp(current: ChatMessage, previous: ChatMessage?) -> Bool {
        guard let previous else { return true }
        
        if current.isMe != previous.isMe {
            return true
        }
        
        let timeGap = current.timestamp.timeIntervalSince(previous.timestamp)
        if timeGap > 5 * 60 {
            return true
        }
        
        return false
    }

    @ViewBuilder
    private func messageBubble(_ msg: ChatMessage, showSeen: Bool, showTimestamp: Bool) -> some View {
        VStack(
            alignment: msg.isMe ? .trailing : .leading,
            spacing: 2
        ) {
            
            if showTimestamp {
                HStack(spacing: 10) {
                    if msg.isMe {
                        Text(" \(msg.timestamp.chatTimestamp())")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(vm.myUserId)
                            .font(.title3)
                            .bold()
                    } else {
                        Text(vm.otherUserId)
                            .font(.title3)
                            .bold()
                        Text(" \(msg.timestamp.chatTimestamp())")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            HStack {
                if msg.isMe { Spacer() }

                Text(msg.text)
                    .foregroundColor(.white)

                if !msg.isMe { Spacer() }
            }

            if showSeen && msg.isMe {
                Text("Seen")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.trailing, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: msg.isMe ? .trailing : .leading)
    }
    
    private var typingIndicatorSection: some View {
        HStack {
            TypingIndicator().padding(.leading)
            Spacer()
        }
        .transition(.opacity)
    }
    
    private var inputBarSection: some View {
        HStack(alignment: .bottom) {
            GrowingTextEditor(text: $vm.messageInput)
                .focused($inputFocused)
                .onChange(of: vm.messageInput) { _, _ in
                    vm.userStartedTyping()
                }

            Button("Send") {
                vm.sendMessage()
                vm.otherUserIsTyping = false
                DispatchQueue.main.async {
                    inputFocused = true
                }
            }
            .padding(.horizontal)
            .disabled(vm.messageInput.isEmpty)
        }
        .padding()
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppConfig.globalBackgroundColorLight)
                .frame(maxHeight: .infinity, alignment: .top),
            alignment: .top
        )
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.backward.circle.fill")
                .font(.system(size: 20))
        }
    }
    
    struct GrowingTextEditor: View {
        @Binding var text: String
        @State private var height: CGFloat = 40

        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppConfig.globalBackgroundColorLight)
                        .frame(height: height)

                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .frame(height: height)
                        .padding(.horizontal, 4)
                        .background(Color.clear)
                        .onChange(of: text) { _, _ in
                            recalcHeight(width: geo.size.width)
                        }

                    if text.isEmpty {
                        Text("Send a message…")
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                            .padding(.top, 8)
                    }
                }
                .onAppear {
                    recalcHeight(width: geo.size.width)
                }
            }
            .frame(height: height)
        }

        private func recalcHeight(width: CGFloat) {
            let size = CGSize(width: width - 16, height: .infinity)
            let bounding = text.boundingRect(
                with: size,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: UIFont.systemFont(ofSize: 17)],
                context: nil
            )
            height = max(40, min(bounding.height + 20, 120))
        }
    }
    
    struct TypingIndicator: View {
        @State private var scale: CGFloat = 1

        var body: some View {
            HStack(spacing: 4) {
                Circle().frame(width: 6, height: 6)
                Circle().frame(width: 6, height: 6)
                Circle().frame(width: 6, height: 6)
            }
            .foregroundColor(.gray)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                    scale = 0.5
                }
            }
            .scaleEffect(scale)
        }
    }

}


extension Date {
    func chatTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }
}

