import SwiftUI


struct ChatRootView: View {

    @ObservedObject var sessionVM: SessionViewModel

    var body: some View {
        
        if let ws = sessionVM.webSocketClient,
           let myId = UserSession.shared.userId {
            let testPartner = "userB"
            let chatVM = ChatViewModel(
                myUserId: myId, otherUserId: testPartner, wsClient: ws
            )

            sessionVM.activeChatVM = chatVM
            ChatView(vm: chatVM)
        } else {
            Text("hey, im connecting!")
        }
        
//        VStack(spacing: 20) {
//            Text("Logged in as \(sessionVM.userIdInput)")
//                .font(.headline)
//            
//            
//
//
//            Button("Logout") {
//                sessionVM.logout()
//            }
//            .padding()
//            .background(Color.red.opacity(0.8))
//            .foregroundColor(.white)
//            .cornerRadius(8)
//        }
    }
}
