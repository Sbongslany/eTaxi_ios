import Foundation

// MARK: - Flexible numeric (handles DB NUMERIC as string)
struct FlexDouble: Decodable {
    let value: Double
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { value = d; return }
        if let s = try? c.decode(String.self), let d = Double(s) { value = d; return }
        value = 0
    }
}

// MARK: - Auth DTOs
struct LoginResponseDTO: Decodable {
    let accessToken:  String
    let refreshToken: String
    let user:         UserDTO
}

struct RegisterResponseDTO: Decodable {
    let message: String
    let userId:  String
    let otp:     String?   // dev only
}

struct MeResponseDTO: Decodable {
    let success: Bool
    let user:    UserDTO
}

struct SuccessResponseDTO: Decodable {
    let success: Bool
    let message: String?
}

// MARK: - User DTO (matches backend snake_case via convertFromSnakeCase decoder)
struct UserDTO: Decodable {
    let id:              String
    let firstName:       String
    let lastName:        String
    let phone:           String
    let email:           String?
    let role:            String
    let status:          String
    let isPhoneVerified: Bool?
    let isFullyVerified: Bool?
    let profilePhotoUrl: String?
    let driverCode:      String?

    // Map to domain entity
    var entity: UserEntity {
        UserEntity(
            id:              id,
            firstName:       firstName,
            lastName:        lastName,
            phone:           phone,
            email:           email,
            role:            role,
            status:          status,
            isPhoneVerified: isPhoneVerified,
            isFullyVerified: isFullyVerified,
            profilePhotoUrl: profilePhotoUrl,
            driverCode:      driverCode
        )
    }
}

// MARK: - Document DTO
struct DocumentDTO: Decodable, Identifiable {
    let id:           String
    let documentType: String
    let status:       String   // "pending" | "approved" | "rejected"
    let url:          String?
    let rejectionReason: String?
    var isApproved:   Bool { status == "approved" }
    var isPending:    Bool { status == "pending" }
}

struct DocumentsResponseDTO: Decodable {
    let success:      Bool
    let documents:    [DocumentDTO]
    let mandatoryDocs: [String]?
}
