import Foundation

// MARK: - Auth Repository Implementation
final class AuthRepositoryImpl: AuthRepositoryProtocol {
    private let api    = AuthAPI.shared
    private let store  = LocalStorage.shared

    func login(phone: String, password: String) async throws -> UserEntity {
        let resp = try await api.login(phone: phone, password: password)
        TokenStore.save(
            access:  resp.accessToken,
            refresh: resp.refreshToken,
            userId:  resp.user.id,
            role:    resp.user.role)
        let entity = resp.user.entity
        store.saveUser(entity)
        return entity
    }

    func register(phone: String, password: String, firstName: String,
                  lastName: String, email: String?, role: String) async throws -> String {
        let resp = try await api.register(
            phone: phone, password: password,
            firstName: firstName, lastName: lastName,
            email: email, role: role)
        if let otp = resp.otp { print("🔑 DEV OTP: \(otp)") }
        return resp.userId
    }

    func verifyOTP(userId: String, code: String) async throws {
        let _ = try await api.verifyOTP(userId: userId, code: code)
    }

    func resendOTP(userId: String) async throws {
        let _ = try await api.resendOTP(userId: userId)
    }

    func getMe() async throws -> UserEntity {
        let resp = try await api.me()
        let entity = resp.user.entity
        store.saveUser(entity)
        return entity
    }

    func logout() {
        TokenStore.clear()
    }
}
