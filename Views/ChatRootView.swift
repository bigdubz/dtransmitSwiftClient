import SwiftUI


struct ChatRootView: View {

    @ObservedObject var sessionVM: SessionViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Logged in as \(sessionVM.userIdInput)")
                .font(.headline)

            Button("Logout") {
                sessionVM.logout()
            }
            .padding()
            .background(Color.red.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}