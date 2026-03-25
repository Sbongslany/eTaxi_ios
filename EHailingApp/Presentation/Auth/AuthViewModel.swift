import SwiftUI
import Combine

// MARK: - Auth Screen
enum AuthScreen: Equatable {
    case splash
    case login
    case register
    case otp
    case vehicleInfo
    case documents
    case passengerHome
    case driverHome
}

// MARK: - Auth View Model
@MainActor
final class AuthViewModel: ObservableObject {

    // Navigation
    @Published var screen: AuthScreen = .splash

    // State
    @Published var isLoading    = false
    @Published var errorMessage: String?

    // Auth data
    @Published var currentUser:    UserEntity?
    @Published var pendingUserId:  String?
    @Published var pendingRole:    String = "passenger"
    @Published var pendingVehicle: VehicleInfoEntity?

    // Documents
    @Published var uploadedDocs:   [DocumentDTO] = []
    @Published var mandatoryDocs:  [String] = []
    @Published var uploadingType:  String?
    @Published var uploadError:    String?

    private let authRepo: AuthRepositoryProtocol

    init(authRepo: AuthRepositoryProtocol = AuthRepositoryImpl()) {
        self.authRepo = authRepo
        checkSession()
    }

    // MARK: - Session Restore
    private func checkSession() {
        guard TokenStore.isLoggedIn else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.screen = .login
            }
            return
        }
        currentUser = LocalStorage.shared.loadUser()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.navigateAfterLogin()
        }
    }

    private func navigateAfterLogin() {
        guard let user = currentUser else { screen = .login; return }
        if user.isDriver {
            if user.isFullyVerified == true {
                screen = .driverHome
            } else {
                screen = .documents
            }
        } else {
            screen = .passengerHome
        }
    }

    // MARK: - Login
    func login(phone: String, password: String) async {
        guard !phone.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your phone number and password"; return
        }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let fullPhone = phone.hasPrefix("+27") ? phone : "+27\(phone.filter { $0.isNumber })"
            currentUser = try await authRepo.login(phone: fullPhone, password: password)
            navigateAfterLogin()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Register (Step 1: user info)
    func register(phone: String, password: String,
                  firstName: String, lastName: String, email: String?, role: String) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let fullPhone = "+27\(phone.filter { $0.isNumber })"
            let userId = try await authRepo.register(
                phone: fullPhone, password: password,
                firstName: firstName, lastName: lastName,
                email: email, role: role)
            pendingUserId = userId
            pendingRole   = role
            if role == "driver" {
                screen = .vehicleInfo
            } else {
                screen = .otp
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Vehicle Info (Step 2 for drivers)
    func submitVehicleInfo(_ info: VehicleInfoEntity) {
        pendingVehicle = info
        screen = .otp
    }

    // MARK: - OTP Verify
        func verifyOTP(code: String) async {
        guard let uid = pendingUserId else { errorMessage = "Session error. Please start over."; return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            try await authRepo.verifyOTP(userId: uid, code: code)
            screen = .login
        } catch { errorMessage = error.localizedDescription }
    }

    func resendOTP() async {
        guard let uid = pendingUserId else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            try await authRepo.resendOTP(userId: uid)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Document Upload
    func uploadDocument(type: String, data: Data, fileName: String, mimeType: String) async {
        uploadingType = type; uploadError = nil
        defer { uploadingType = nil }
        do {
            let _ = try await AuthAPI.shared.uploadDocument(
                type: type, data: data, fileName: fileName, mimeType: mimeType)
            await loadDocuments()
        } catch {
            uploadError = error.localizedDescription
        }
    }

    func loadDocuments() async {
        do {
            let resp = try await AuthAPI.shared.getDocuments()
            uploadedDocs  = resp.documents
            mandatoryDocs = resp.mandatoryDocs ?? []
        } catch {}
    }

    func proceedFromDocuments() {
        screen = .driverHome
    }

    // MARK: - Logout
    func logout() {
        authRepo.logout()
        currentUser = nil
        pendingUserId = nil
        screen = .login
    }

    var uploadedDocTypes: Set<String> { Set(uploadedDocs.map { $0.documentType }) }
    var allMandatoryUploaded: Bool { mandatoryDocs.allSatisfy { uploadedDocTypes.contains($0) } }
    var uploadProgress: Double {
        guard !mandatoryDocs.isEmpty else { return 0 }
        return Double(uploadedDocs.count) / Double(mandatoryDocs.isEmpty ? 10 : mandatoryDocs.count)
    }
}
