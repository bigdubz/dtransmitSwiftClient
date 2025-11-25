import SwiftUI


struct ContentView: View {
    
    @StateObject private var sessionVM = SessionViewModel()

    var body: some View {
        Group {
            if sessionVM.isLoggedIn {
                ChatRootView(sessionVM: sessionVM)
            } else {
                LoginView(sessionVM: sessionVM)
            }
        }
    }
}

