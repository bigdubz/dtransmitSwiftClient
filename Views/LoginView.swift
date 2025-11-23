import SwiftUI

struct LoginView: View {
    @ObservedObject var sessionVM: SessionViewModel

    var body: some View {
        VStack(spacing: 20) {
            
            Text("Login")
                .font(.title)
                .padding(.bottom, 20)

            TextField("Username", text: $sessionVM.userIdInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal)

            SecureField("Password", text: $sessionVM.passwordInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            if let error = sessionVM.loginError {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            if sessionVM.isLoading {
                ProgressView("Logging in...")
                    .padding()
            } else {
                Button(action: {
                    Task { await sessionVM.login() }
                }) {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                .disabled(sessionVM.userIdInput.isEmpty || sessionVM.passwordInput.isEmpty)
            }

            Spacer()
        }
    }
}