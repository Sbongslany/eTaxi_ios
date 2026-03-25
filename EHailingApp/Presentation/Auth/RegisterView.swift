import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var phone     = ""
    @State private var email     = ""
    @State private var password  = ""
    @State private var role      = "passenger"

    @Environment(\.dismiss) var dismiss

    var canProceed: Bool {
        !firstName.isEmpty && !lastName.isEmpty &&
        phone.count >= 9 && password.count >= Constants.Auth.minPassword
    }

    var buttonTitle: String {
        role == "driver" ? "Next: Vehicle Info →" : "Create Account"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.eBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Progress bar
                        HStack(spacing: 8) {
                            Capsule().fill(Color.eGreen).frame(height: 3)
                            Capsule().fill(role == "driver" ? Color.eSurface : Color.clear)
                                .frame(height: 3)
                        }
                        .padding(.bottom, 24)

                        Text("Create Account")
                            .font(EFont.display(26, weight: .heavy))
                            .foregroundColor(.eText)
                            .padding(.bottom, 6)
                        Text("Fill in your details to get started")
                            .font(EFont.body(15))
                            .foregroundColor(.eTextSoft)
                            .padding(.bottom, 28)

                        // First + Last name
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                EFieldLabel(text: "First Name")
                                ETextField(placeholder: "Thabo", text: $firstName)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                EFieldLabel(text: "Last Name")
                                ETextField(placeholder: "Khumalo", text: $lastName)
                            }
                        }
                        .padding(.bottom, 16)

                        // Phone
                        VStack(alignment: .leading, spacing: 8) {
                            EFieldLabel(text: "Phone Number")
                            EPhoneField(text: $phone)
                        }
                        .padding(.bottom, 16)

                        // Email
                        VStack(alignment: .leading, spacing: 8) {
                            EFieldLabel(text: "Email (Optional)")
                            ETextField(placeholder: "you@email.com", text: $email,
                                       keyboard: .emailAddress)
                        }
                        .padding(.bottom, 16)

                        // Password
                        VStack(alignment: .leading, spacing: 8) {
                            EFieldLabel(text: "Password")
                            ETextField(placeholder: "Min 8 characters", text: $password,
                                       isSecure: true)
                        }
                        .padding(.bottom, 20)

                        // Account Type Toggle
                        VStack(alignment: .leading, spacing: 10) {
                            EFieldLabel(text: "Account Type")

                            HStack(spacing: 0) {
                                roleButton("🧑  Passenger", value: "passenger")
                                roleButton("🚗  Driver",    value: "driver")
                            }
                            .background(Color.eSurface)
                            .clipShape(RoundedRectangle(cornerRadius: ERadius.sm))
                        }
                        .padding(.bottom, 12)

                        // Driver info banner
                        if role == "driver" {
                            EInfoBanner(
                                message: "As a driver you'll need to upload documents and vehicle info")
                                .padding(.bottom, 12)
                        }

                        // Error
                        if let err = authVM.errorMessage {
                            EErrorBanner(message: err).padding(.bottom, 12)
                        }

                        // CTA
                        EPrimaryButton(
                            title: buttonTitle,
                            isLoading: authVM.isLoading,
                            isDisabled: !canProceed
                        ) {
                            Task {
                                await authVM.register(
                                    phone: phone, password: password,
                                    firstName: firstName, lastName: lastName,
                                    email: email.isEmpty ? nil : email,
                                    role: role)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        authVM.errorMessage = nil
                        authVM.screen = .login
                    }
                    .foregroundColor(.eTextSoft)
                    .padding(.horizontal, 4).padding(.vertical, 6)
                    .background(Color.eSurface)
                    .clipShape(Capsule())
                }
            }
        }
        .onAppear { authVM.errorMessage = nil }
    }

    @ViewBuilder
    private func roleButton(_ label: String, value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { role = value }
        } label: {
            Text(label)
                .font(EFont.body(14, weight: .semibold))
                .foregroundColor(role == value ? .black : .eTextSoft)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(role == value ? Color.eGreen : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: ERadius.sm))
        }
    }
}
