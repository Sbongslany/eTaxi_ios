import Foundation

// MARK: - Auth Repository Protocol
protocol AuthRepositoryProtocol {
    func login(phone: String, password: String) async throws -> UserEntity
    func register(phone: String, password: String, firstName: String,
                  lastName: String, email: String?, role: String) async throws -> String // returns userId
    func verifyOTP(userId: String, code: String) async throws
    func resendOTP(userId: String) async throws
    func getMe() async throws -> UserEntity
    func logout()
}
