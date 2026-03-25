import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var phone    = ""
    @State private var password = ""

    var canSignIn: Bool { phone.count >= 9 && password.count >= Constants.Auth.minPassword }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Logo + App name
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.eGreen)
                            .frame(width: 36, height: 36)
                        Text("eT")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                    }
                    HStack(spacing: 0) {
                        Text("e").font(EFont.display(20, weight: .black)).foregroundColor(.eText)
                        Text("Taxi").font(EFont.display(20, weight: .black)).foregroundColor(.eGreen)
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 32)

                // Title
                Text("Welcome back 👋")
                    .font(EFont.display(28, weight: .heavy))
                    .foregroundColor(.eText)
                    .padding(.bottom, 6)
                Text("Sign in to continue")
                    .font(EFont.body(15))
                    .foregroundColor(.eTextSoft)
                    .padding(.bottom, 32)

                // Phone
                VStack(alignment: .leading, spacing: 8) {
                    EFieldLabel(text: "Phone Number")
                    EPhoneField(text: $phone)
                }
                .padding(.bottom, 18)

                // Password
                VStack(alignment: .leading, spacing: 8) {
                    EFieldLabel(text: "Password")
                    ETextField(placeholder: "Enter your password",
                               text: $password, isSecure: true)
                }
                .padding(.bottom, 10)

                // Forgot password
                HStack {
                    Spacer()
                    Button("Forgot password?") {}
                        .font(EFont.body(14, weight: .semibold))
                        .foregroundColor(.eGreen)
                }
                .padding(.bottom, 24)

                // Error
                if let err = authVM.errorMessage {
                    EErrorBanner(message: err).padding(.bottom, 16)
                }

                // Sign In
                EPrimaryButton(
                    title: "Sign In",
                    isLoading: authVM.isLoading,
                    isDisabled: !canSignIn
                ) {
                    Task { await authVM.login(phone: phone, password: password) }
                }
                .padding(.bottom, 16)

                // Divider
                HStack {
                    Rectangle().fill(Color.eBorder).frame(height: 1)
                    Text("OR").font(EFont.body(12, weight: .semibold))
                        .foregroundColor(.eTextMuted).padding(.horizontal, 12)
                    Rectangle().fill(Color.eBorder).frame(height: 1)
                }
                .padding(.bottom, 16)

                // Create Account
                ESecondaryButton(title: "Create an account") {
                    authVM.errorMessage = nil
                    authVM.screen = .register
                }
                .padding(.bottom, 8)

                Text("Works for both passengers and drivers")
                    .font(EFont.body(13))
                    .foregroundColor(.eTextMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.eBackground.ignoresSafeArea())
    }
}
