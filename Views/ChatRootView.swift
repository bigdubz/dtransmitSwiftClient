import SwiftUI


struct ChatRootView: View {

    @ObservedObject var sessionVM: SessionViewModel

    var body: some View {
        if sessionVM.isLoggedIn {
            NavigationStack {
                ChatListView(sessionVM: sessionVM)
            }
        } else {
            Text("Not logged in.")
        }
    }
}
