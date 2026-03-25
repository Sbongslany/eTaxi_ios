import SwiftUI

// MARK: - Colors (matching screenshots: #090C10 bg, #00E574 green, #FFCE00 accent)
extension Color {
    static let eBackground  = Color(hex: "#090C10")
    static let eCard        = Color(hex: "#111418")
    static let eSurface     = Color(hex: "#181D24")
    static let eSurface2    = Color(hex: "#1E252F")
    static let eBorder      = Color(hex: "#252B35")
    static let eText        = Color(hex: "#EEF2F8")
    static let eTextSoft    = Color(hex: "#9AA3B0")
    static let eTextMuted   = Color(hex: "#5A6472")
    static let eGreen       = Color(hex: "#00E574")
    static let eGreenDim    = Color(hex: "#00B85A")
    static let eAccent      = Color(hex: "#FFCE00")
    static let eRed         = Color(hex: "#FF4444")
    static let eBlue        = Color(hex: "#4488FF")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16&0xFF,int>>8&0xFF,int&0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Typography
enum EFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}

// MARK: - Radius
enum ERadius {
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 20
    static let xl:  CGFloat = 24
    static let full: CGFloat = 100
}

// MARK: - Shared Field Label
struct EFieldLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(EFont.body(11, weight: .bold))
            .foregroundColor(.eTextMuted)
            .kerning(0.8)
    }
}

// MARK: - Shared Text Field
struct ETextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var isSecure = false
    @State private var showText = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Group {
                if isSecure && !showText {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboard)
                }
            }
            .font(EFont.body(16))
            .foregroundColor(.eText)
            .focused($focused)

            if isSecure {
                Button { showText.toggle() } label: {
                    Image(systemName: showText ? "eye.slash" : "eye")
                        .font(.system(size: 16))
                        .foregroundColor(.eTextMuted)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 16)
        .background(Color.eSurface)
        .clipShape(RoundedRectangle(cornerRadius: ERadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: ERadius.sm)
                .stroke(focused ? Color.eGreen.opacity(0.5) : Color.eBorder, lineWidth: 1.5)
        )
    }
}

// MARK: - Phone Field
struct EPhoneField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("🇿🇦")
                    .font(.system(size: 20))
                Text("+27")
                    .font(EFont.body(16, weight: .semibold))
                    .foregroundColor(.eText)
            }
            .padding(.horizontal, 14).padding(.vertical, 16)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.eBorder)
                    .frame(width: 1)
            }

            TextField("82 456 7890", text: $text)
                .font(EFont.body(16))
                .foregroundColor(.eText)
                .keyboardType(.phonePad)
                .focused($focused)
                .padding(.horizontal, 14)
        }
        .background(Color.eSurface)
        .clipShape(RoundedRectangle(cornerRadius: ERadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: ERadius.sm)
                .stroke(focused ? Color.eGreen.opacity(0.5) : Color.eBorder, lineWidth: 1.5)
        )
    }
}

// MARK: - Primary Button
struct EPrimaryButton: View {
    let title: String
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: ERadius.md)
                    .fill(isDisabled ? Color.eSurface : Color.eGreen)
                if isLoading {
                    ProgressView().tint(.black)
                } else {
                    Text(title)
                        .font(EFont.body(16, weight: .bold))
                        .foregroundColor(isDisabled ? .eTextMuted : .black)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 56)
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Secondary Button
struct ESecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(EFont.body(16, weight: .semibold))
                .foregroundColor(.eText)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(Color.eSurface)
                .clipShape(RoundedRectangle(cornerRadius: ERadius.md))
                .overlay(RoundedRectangle(cornerRadius: ERadius.md)
                    .stroke(Color.eBorder, lineWidth: 1.5))
        }
    }
}

// MARK: - Back Button
struct EBackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Back")
                    .font(EFont.body(15, weight: .semibold))
            }
            .foregroundColor(.eGreen)
        }
    }
}

// MARK: - Error Banner
struct EErrorBanner: View {
    let message: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.eRed)
            Text(message)
                .font(EFont.body(13))
                .foregroundColor(.eRed)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.eRed.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: ERadius.sm))
        .overlay(RoundedRectangle(cornerRadius: ERadius.sm)
            .stroke(Color.eRed.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Info Banner
struct EInfoBanner: View {
    let message: String
    var color: Color = .eAccent
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundColor(color)
            Text(message)
                .font(EFont.body(13)).foregroundColor(.eTextSoft)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: ERadius.sm))
        .overlay(RoundedRectangle(cornerRadius: ERadius.sm)
            .stroke(color.opacity(0.25), lineWidth: 1))
    }
}
