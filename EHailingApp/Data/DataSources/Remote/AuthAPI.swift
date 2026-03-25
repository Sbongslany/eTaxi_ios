import Foundation

// MARK: - Auth Remote API
final class AuthAPI {
    static let shared = AuthAPI()
    private let api = APIClient.shared
    private init() {}

    func login(phone: String, password: String) async throws -> LoginResponseDTO {
        try await api.request(
            "/auth/login", method: .POST,
            body: ["phone": phone, "password": password],
            authenticated: false)
    }

    func register(phone: String, password: String, firstName: String,
                  lastName: String, email: String?, role: String) async throws -> RegisterResponseDTO {
        var body: [String: Any] = [
            "phone": phone, "password": password,
            "firstName": firstName, "lastName": lastName,
            "role": role, "popiaConsent": true
        ]
        if let e = email, !e.isEmpty { body["email"] = e }
        return try await api.request("/auth/register", method: .POST, body: body, authenticated: false)
    }

    func verifyOTP(userId: String, code: String) async throws -> SuccessResponseDTO {
        try await api.request(
            "/auth/verify-phone", method: .POST,
            body: ["userId": userId, "code": code, "purpose": "phone_verify"],
            authenticated: false)
    }

    func resendOTP(userId: String) async throws -> SuccessResponseDTO {
        try await api.request(
            "/auth/resend-otp", method: .POST,
            body: ["userId": userId, "purpose": "phone_verify"],
            authenticated: false)
    }

    func me() async throws -> MeResponseDTO {
        try await api.request("/auth/me")
    }

    func uploadDocument(type: String, data: Data, fileName: String, mimeType: String) async throws -> UploadResponse {
        try await api.upload(
            "/documents/upload",
            fileData: data, fileName: fileName, mimeType: mimeType,
            fields: ["documentType": type])
    }

    func getDocuments() async throws -> DocumentsResponseDTO {
        try await api.request("/documents/my")
    }
}
