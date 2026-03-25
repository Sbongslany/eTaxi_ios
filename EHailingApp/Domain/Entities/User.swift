import Foundation

// MARK: - User Entity (domain model)
struct UserEntity: Codable, Identifiable, Equatable {
    let id:              String
    var firstName:       String
    var lastName:        String
    var phone:           String
    var email:           String?
    var role:            String       // "passenger" | "driver"
    var status:          String       // "active" | "pending_verification" | "suspended"
    var isPhoneVerified: Bool?
    var isFullyVerified: Bool?
    var profilePhotoUrl: String?
    var driverCode:      String?

    var fullName:    String { "\(firstName) \(lastName)" }
    var initials:    String { "\(firstName.prefix(1))\(lastName.prefix(1))".uppercased() }
    var isDriver:    Bool   { role == "driver" }
    var isPassenger: Bool   { role == "passenger" }
    var needsDocuments: Bool { isDriver && isFullyVerified != true }
}

// MARK: - Vehicle Info (for driver registration)
struct VehicleInfoEntity {
    var make:         String = ""
    var model:        String = ""
    var year:         String = ""
    var colour:       String = ""
    var registration: String = ""
    var vehicleType:  String = "Sedan"

    static let types = ["Sedan", "Hatchback", "SUV", "Minivan", "Bakkie"]

    var isValid: Bool {
        !make.isEmpty && !model.isEmpty && !year.isEmpty &&
        !colour.isEmpty && !registration.isEmpty && year.count == 4
    }
}
