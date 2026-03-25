import SwiftUI

struct OTPView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var digits   = Array(repeating: "", count: 6)
    @State private var fullText = ""
    @State private var resendCooldown = 0
    @FocusState private var focused: Bool

    var fullOTP: String { digits.joined() }
    var isComplete: Bool { digits.allSatisfy { $0.count == 1 } }

    var body: some View {
        ZStack {
            Color.eBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.eGreen.opacity(0.12))
                        .frame(width: 88, height: 88)
                    Image(systemName: "message.badge.filled.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.eGreen)
                }
                .padding(.bottom, 28)

                Text("Check your SMS")
                    .font(EFont.display(26, weight: .heavy))
                    .foregroundColor(.eText)
                    .padding(.bottom, 10)

                Text("Enter the 6-digit code we sent to your number")
                    .font(EFont.body(15))
                    .foregroundColor(.eTextSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)

                // OTP Boxes
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { i in
                        ZStack {
                            RoundedRectangle(cornerRadius: ERadius.sm)
                                .fill(Color.eSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ERadius.sm)
                                        .stroke(
                                            digits[i].isEmpty
                                                ? Color.eBorder
                                                : Color.eGreen,
                                            lineWidth: digits[i].isEmpty ? 1.5 : 2)
                                )
                                .frame(width: 48, height: 58)

                            Text(digits[i].isEmpty ? "" : digits[i])
                                .font(EFont.mono(22))
                                .foregroundColor(.eText)
                        }
                    }
                }
                .padding(.bottom, 32)

                // Hidden input
                TextField("", text: $fullText)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .opacity(0)
                    .frame(width: 1, height: 1)
                    .onChange(of: fullText) { val in
                        let nums = String(val.filter { $0.isNumber }.prefix(6))
                        for i in 0..<6 {
                            digits[i] = i < nums.count
                                ? String(nums[nums.index(nums.startIndex, offsetBy: i)])
                                : ""
                        }
                        if isComplete {
                            Task { await authVM.verifyOTP(code: fullOTP) }
                        }
                    }

                // Error
                if let err = authVM.errorMessage {
                    EErrorBanner(message: err)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                }

                // Verify button
                EPrimaryButton(
                    title: "Verify Code",
                    isLoading: authVM.isLoading,
                    isDisabled: !isComplete
                ) {
                    Task { await authVM.verifyOTP(code: fullOTP) }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                // Resend
                Button {
                    guard resendCooldown == 0 else { return }
                    resendCooldown = 30
                    fullText = ""
                    digits = Array(repeating: "", count: 6)
                    Task {
                        await authVM.resendOTP()
                        startCooldown()
                    }
                } label: {
                    Text(resendCooldown > 0
                         ? "Resend in \(resendCooldown)s"
                         : "Resend code")
                        .font(EFont.body(15, weight: .semibold))
                        .foregroundColor(resendCooldown > 0 ? .eTextMuted : .eGreen)
                }

                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
        }
        .onTapGesture { focused = true }
    }

    private func startCooldown() {
        guard resendCooldown > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            resendCooldown -= 1
            startCooldown()
        }
    }
}
