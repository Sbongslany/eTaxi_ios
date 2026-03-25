import SwiftUI

@main
struct EHailingApp: App {
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authVM)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Root View
struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Group {
            switch authVM.screen {
            case .splash:           SplashView()
            case .login:            LoginView()
            case .register:         RegisterView()
            case .otp:              OTPView()
            case .vehicleInfo:      VehicleInfoView()
            case .documents:        DocumentUploadView()
            case .passengerHome:    Text("Passenger Home") // placeholder
            case .driverHome:       Text("Driver Home")    // placeholder
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.screen)
    }
}
