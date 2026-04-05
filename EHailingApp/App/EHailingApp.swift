import SwiftUI

@main
struct EHailingApp: App {
    @StateObject private var authVM = AuthViewModel()
    // Force LocationManager singleton onto main thread at app launch
    private let _loc = LocationManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authVM)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Root View (wires auth screen → passenger/driver home)
struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Group {
            switch authVM.screen {
            case .splash:        SplashView()
            case .login:         LoginView()
            case .register:      RegisterView()
            case .otp:           OTPView()
            case .vehicleInfo:   VehicleInfoView()
            case .documents:     DocumentUploadView()
            case .passengerHome:
                if let user = authVM.currentUser {
                    PassengerRoot(user: user)
                } else {
                    LoginView()
                }
            case .driverHome:
                if let user = authVM.currentUser {
                    DriverRoot(user: user)
                } else {
                    LoginView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.screen)
    }
}
