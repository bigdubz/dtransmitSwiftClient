import SwiftUI


struct ChatView: View {
    @ObservedObject var vm: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Keyboard focus
    @FocusState private var inputFocused: Bool
    
    @State private var scrollToBottomRequest = false
    @State private var scrollPosition: ChatMessage.ID?
    
    // Convenience: ID of the last seen message
    var lastSeenMessageId: String? {
        vm.messages
            .filter { $0.isMe }
            .last(where: { $0.isSeen })?.id
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            messagesSection
            
            if let r = vm.isReplyingTo {
                HStack {
                    replyPreview(r)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 6)
            }
            
            inputBarSection
        }
        .background(AppConfig.globalBackgroundColor)
        
        // GLOBAL TAP TO DISMISS KEYBOARD
        .onTapGesture {
            inputFocused = false
            scrollToBottomRequest = true
        }
        
        .navigationTitle("\(vm.otherUserId)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.loadInitialHistory()
            scrollToBottomRequest = true
        }
        .onDisappear {
            vm.didInitialScrollToBottom = false
        }
    }
    
    private func replyPreview(_ r: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(AppConfig.globalBackgroundColorLight)
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(r.isMe ? "You" : vm.otherUserId)
                    .font(.caption)
                    .bold()
                Text(r.text)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            Button {
                vm.isReplyingTo = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(AppConfig.globalBackgroundColorLight)
        .cornerRadius(10)
        .padding(.horizontal)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private var messagesSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    
                    topHistoryLoader(proxy: proxy)
                    
                    ForEach(vm.messages, id: \.id) { msg in
                        let prev: ChatMessage? = {
                            guard let idx = vm.messages.firstIndex(where: { $0.id == msg.id }),
                                  idx > 0 else { return nil }
                            return vm.messages[idx - 1]
                        }()
                        
                        messageRow(for: msg, previous: prev)
                            .id(msg.id)
                    }
                }
                .padding()
            }
            
            // Auto-scroll when "seen" changes
            .onChange(of: lastSeenMessageId) { _, newValue in
                guard vm.didInitialScrollToBottom else { return }
                withAnimation {
                    print("lastSeen")
                    proxy.scrollTo(newValue, anchor: .bottom)
                }
            }
            
            // Auto-scroll on new messages
            .onChange(of: vm.messages) { oldValue, newValue in
                guard vm.didInitialScrollToBottom else { return }
                guard let oldLast = oldValue.last, let newLast = newValue.last else { return }
                guard oldLast.id != newLast.id else { return }
                
                withAnimation {
                    print("new message")
                    proxy.scrollTo(newLast.id, anchor: .bottom)
                }
                
                if !newLast.isMe {
                    vm.markMessageAsSeen(messageId: newLast.id)
                }
            }
            
            .onChange(of: scrollToBottomRequest) { _, shouldScroll in
                guard shouldScroll else { return }
                scrollToBottomRequest = false
                if let last = vm.messages.last {
                    withAnimation(.none) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                vm.didInitialScrollToBottom = true
            }
        }
    }
    
    // Extracted to reduce ViewBuilder complexity
    @ViewBuilder
    private func messageRow(for msg: ChatMessage, previous: ChatMessage?) -> some View {
        let showTimestamp = shouldShowTimestamp(current: msg, previous: previous)
        let showSeen = (msg.id == lastSeenMessageId)
        
        MessageBubbleRow(
            msg: msg,
            showSeen: showSeen,
            showTimestamp: showTimestamp
        )
        .environmentObject(vm)
    }
    
    private func topHistoryLoader(proxy: ScrollViewProxy) -> some View {
        Color.clear
            .frame(height: 1)
            .id("TOP_SENTINEL")
            .onAppear {
                guard !vm.isLoadingOlderMessages else { return }
                guard vm.didInitialScrollToBottom else { return }
                guard let first = vm.messages.first else { return }
                vm.isLoadingOlderMessages = true
                
                Task {
                    await vm.loadOlderHistory(before: first.timestamp)
                    withAnimation(.none) {
                        proxy.scrollTo(first.id, anchor: .center)
                    }
                    vm.isLoadingOlderMessages = false
                }
            }
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
    
    private var typingIndicatorSection: some View {
        HStack(spacing: 5) {
            TypingIndicator().padding(.leading)
            Text("\(vm.otherUserId) is typing...")
                .font(.footnote)
            Spacer()
        }
        .transition(.opacity)
    }

    private var inputBarSection: some View {
        VStack(spacing: 5) {
            HStack(alignment: .bottom) {
                GrowingTextEditor(text: $vm.messageInput)
                    .focused($inputFocused)
                    .onChange(of: vm.messageInput) { _, _ in
                        vm.userStartedTyping()
                    }
                
                Button("Send") {
                    vm.sendMessage()
                    vm.stopTyping()
                    vm.isReplyingTo = nil
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
            ZStack {
                if vm.otherUserIsTyping {
                    typingIndicatorSection
                }
            }
            .frame(height: 15)
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

    struct MessageBubbleRow: View {
        let msg: ChatMessage
        let showSeen: Bool
        let showTimestamp: Bool
        @State private var dragOffset: CGFloat = 0
        @EnvironmentObject var vm: ChatViewModel

        var body: some View {
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
                
                if let reply = msg.replyingTo {
                    replyPreview(replyId: reply)
                        .padding(.top, showTimestamp ? 0 : 10)
                }
                
                HStack {
                    if msg.isMe { Spacer() }
                    
                    Text(msg.text)
                        .font(.callout)
                        .foregroundColor(.white)
                        .multilineTextAlignment(msg.isMe ? .trailing : .leading)
                    
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
            .offset(x: dragOffset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onChanged { value in
                        if value.translation.width > 0 {
                            dragOffset = min(value.translation.width, 60)
                        }
                    }
                    .onEnded { _ in
                        if dragOffset > 50 {
                            vm.isReplyingTo = msg
                        }
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
            )
            .contextMenu {
                Button("Reply") {
                    vm.isReplyingTo = msg
                }
            }
        }
        
        @ViewBuilder
        private func replyPreview(replyId: String) -> some View {
            let replyToMsg = vm.messages.first(where: { $0.id == replyId })
            let replyingToText: String = {
                if msg.isMe {
                    return (replyToMsg?.isMe ?? true)
                        ? "Replying to yourself"
                        : "Replying to \(vm.otherUserId)"
                } else {
                    return (replyToMsg?.isMe ?? true)
                        ? "Replying to you"
                        : "Replying to themselves"
                }
            }()

            HStack {
                if msg.isMe { Spacer() }

                HStack(alignment: .top, spacing: 6) {
                    Rectangle()
                        .fill(AppConfig.globalBackgroundColorLight)
                        .frame(width: 3)

                    VStack(alignment: msg.isMe ? .trailing : .leading, spacing: 2) {
                        Text(replyingToText)
                            .font(.caption)
                            .bold()
                            .foregroundColor(Color.white.opacity(0.9))

                        Text(replyToMsg?.text ?? "Message not found")
                            .font(.caption2)
                            .foregroundColor(Color.gray)
                            .lineLimit(2)
                    }
                }
                .padding(4)
                .padding(.trailing, 3)
                .background(AppConfig.globalBackgroundColorLight)
                .cornerRadius(6)
                .frame(maxWidth: 250, alignment: msg.isMe ? .trailing : .leading)

                if !msg.isMe { Spacer() }
            }
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
            .padding(.leading, 12)
            .cornerRadius(10)
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
