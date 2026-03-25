import SwiftUI

struct SplashView: View {
    @State private var logoScale:   CGFloat = 0.6
    @State private var logoOpacity: Double  = 0
    @State private var glowOpacity: Double  = 0
    @State private var ringScale:   CGFloat = 0.3

    var body: some View {
        ZStack {
            Color.eBackground.ignoresSafeArea()

            // Glow
            RadialGradient(
                colors: [Color.eGreen.opacity(0.18), Color.clear],
                center: .center, startRadius: 0, endRadius: 260)
                .frame(width: 520, height: 520)
                .opacity(glowOpacity)

            // Rings
            ForEach([160, 240, 320], id: \.self) { size in
                Circle()
                    .stroke(Color.eGreen.opacity(0.06), lineWidth: 1)
                    .frame(width: CGFloat(size), height: CGFloat(size))
                    .scaleEffect(ringScale)
            }

            VStack(spacing: 20) {
                // Logo mark
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.eGreen)
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.eGreen.opacity(0.4), radius: 30, y: 8)

                    Text("eT")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 6) {
                    HStack(spacing: 2) {
                        Text("e")
                            .font(EFont.display(32, weight: .black))
                            .foregroundColor(.eText)
                        Text("Taxi")
                            .font(EFont.display(32, weight: .black))
                            .foregroundColor(.eGreen)
                    }
                    Text("Your ride, your way")
                        .font(EFont.body(14))
                        .foregroundColor(.eTextMuted)
                }
                .opacity(logoOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.2)) {
                logoScale = 1; logoOpacity = 1
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.1)) {
                glowOpacity = 1; ringScale = 1
            }
        }
    }
}
