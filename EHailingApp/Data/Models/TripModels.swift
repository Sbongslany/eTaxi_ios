import Foundation
import CoreLocation
import SwiftUI

// NOTE: UserEntity, VehicleInfoEntity, DocumentDTO defined in Domain/Entities/User.swift
// MapPin defined in Presentation/Shared/MapComponents.swift

// MARK: - Shared response
struct SuccessMsg: Decodable { let success: Bool; let message: String? }

// MARK: - BETrip (manual Decodable handles Double/String from PostgreSQL NUMERIC)
struct BETrip: Identifiable, Decodable {
    let id:            String
    var status:        String
    var rideType:      String
    var pickupAddress:  String
    var dropoffAddress: String
    var pickupLat:     Double
    var pickupLon:     Double
    var dropoffLat:    Double
    var dropoffLon:    Double
    var totalFare:            Double?
    var estimatedDurationMin: Double?
    var estimatedDistanceKm:  Double?
    var driverName:    String?
    var driverCode:    String?
    var vehicleInfo:   String?
    var scheduledAt:   String?
    var hireHours:     Int?
    var hireDays:      Int?
    var passengerId:   String?
    var driverId:      String?

    var pickupCoord:  CLLocationCoordinate2D { .init(latitude: pickupLat,  longitude: pickupLon) }
    var dropoffCoord: CLLocationCoordinate2D { .init(latitude: dropoffLat, longitude: dropoffLon) }
    var fareStr:  String { totalFare.map { "R\(Int($0))" } ?? "R0" }
    var etaStr:   String { estimatedDurationMin.map { "\(Int($0)) min" } ?? "—" }
    var isActive: Bool   { ["accepted","driver_en_route","driver_arrived","in_progress"].contains(status) }
    var canCancel: Bool  { ["searching","accepted","driver_en_route","driver_arrived"].contains(status) }
    var isCustom: Bool   { rideType == "custom" }

    var statusLabel: String {
        switch status {
        case "searching":         return "Finding driver…"
        case "accepted":          return "Driver accepted"
        case "driver_en_route":   return "Driver on the way"
        case "driver_arrived":    return "Driver has arrived!"
        case "in_progress":       return "In progress"
        case "completed":         return "Completed"
        case "no_driver_found":   return "No driver found"
        case "cancelled_passenger","cancelled_driver","cancelled_system": return "Cancelled"
        default: return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var passengerName:  String?
    var driverEarnings: Double?

    enum CodingKeys: String, CodingKey {
        case id, status, rideType, pickupAddress, dropoffAddress
        case pickupLat, pickupLon, dropoffLat, dropoffLon
        case totalFare, estimatedDurationMin, estimatedDistanceKm
        case driverName, driverCode, vehicleInfo
        case scheduledAt, hireHours, hireDays, passengerId, driverId
        case passengerName, driverEarnings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(String.self, forKey: .id)
        status         = try c.decode(String.self, forKey: .status)
        rideType       = (try? c.decode(String.self, forKey: .rideType))       ?? "standard"
        pickupAddress  = (try? c.decode(String.self, forKey: .pickupAddress))  ?? ""
        dropoffAddress = (try? c.decode(String.self, forKey: .dropoffAddress)) ?? ""
        pickupLat      = Self.flexDouble(c, .pickupLat)
        pickupLon      = Self.flexDouble(c, .pickupLon)
        dropoffLat     = Self.flexDouble(c, .dropoffLat)
        dropoffLon     = Self.flexDouble(c, .dropoffLon)
        totalFare            = Self.optDouble(c, .totalFare)
        estimatedDurationMin = Self.optDouble(c, .estimatedDurationMin)
        estimatedDistanceKm  = Self.optDouble(c, .estimatedDistanceKm)
        driverName    = try? c.decode(String.self, forKey: .driverName)
        driverCode    = try? c.decode(String.self, forKey: .driverCode)
        vehicleInfo   = try? c.decode(String.self, forKey: .vehicleInfo)
        scheduledAt   = try? c.decode(String.self, forKey: .scheduledAt)
        hireHours     = try? c.decode(Int.self, forKey: .hireHours)
        hireDays      = try? c.decode(Int.self, forKey: .hireDays)
        passengerId   = try? c.decode(String.self, forKey: .passengerId)
        driverId      = try? c.decode(String.self, forKey: .driverId)
        passengerName = try? c.decode(String.self, forKey: .passengerName)
        driverEarnings = Self.optDouble(c, .driverEarnings)
    }

    private static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double {
        if let d = try? c.decode(Double.self, forKey: k) { return d }
        if let s = try? c.decode(String.self, forKey: k), let d = Double(s) { return d }
        return 0
    }
    private static func optDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: k) { return d }
        if let s = try? c.decode(String.self, forKey: k), let d = Double(s) { return d }
        return nil
    }
}

struct TripSingleResponse: Decodable { let success: Bool; let trip: BETrip }
struct TripListResponse:   Decodable { let success: Bool; let trips: [BETrip] }

// MARK: - Services
struct BERideService: Decodable, Identifiable {
    let id: String; let key: String; let name: String
    let icon: String; let vehicleType: String; let maxPassengers: Int
    let serviceType: String; let minimumFare: Double
    let perHour: Double?; let perDay: Double?; let isActive: Bool
    var isCustomHire: Bool { serviceType == "custom" }
    var isStandard:   Bool { serviceType == "standard" }
    var emoji: String {
        switch key {
        case "economy": return "🚗"; case "comfort": return "🚙"
        case "xl":      return "🚐"; case "ladies":  return "💜"
        default:        return "🚖"
        }
    }
    var displayPrice: String {
        if isCustomHire, let h = perHour { return "R\(Int(h))/hr" }
        return "From R\(Int(minimumFare))"
    }
}

struct BEServiceCategory: Decodable, Identifiable {
    let id: String; let key: String; let name: String; let icon: String
    var services: [BERideService] = []
}

struct ServicesResponse:  Decodable { let success: Bool; let categories: [BEServiceCategory] }
struct EstimateResponse:  Decodable {
    let success: Bool?; let estimated: Double?; let min: Double?
    let max: Double?; let distanceKm: Double?; let durationMin: Double?
}

// MARK: - Driver profile
struct BEDriverProfile: Decodable {
    let id: String
    var isOnline:       Bool
    var isAvailable:    Bool
    var driverCode:     String?
    var vehicleMake:    String?
    var vehicleModel:   String?
    var vehicleColor:   String?
    var vehicleReg:     String?
    var vehicleType:    String?
    var totalTrips:     Int
    var totalEarnings:  Double
    var acceptanceRate: Double
    var currentLat:     Double?
    var currentLon:     Double?
    var isVerified:         Bool   { true } // dev: all drivers verified
    var vehicleRegistration: String? { vehicleReg }
    var vehicleDisplay: String {
        [vehicleMake, vehicleModel, vehicleColor].compactMap { $0 }.joined(separator: " ")
    }
}
struct DriverProfileResponse: Decodable { let success: Bool; let profile: BEDriverProfile }

struct BEEarnings: Decodable {
    let today: String?; let thisWeek: String?; let thisMonth: String?
    let totalTrips: Int?; let totalEarned: String?; let avgPerTrip: String?
    enum CodingKeys: String, CodingKey {
        case today; case thisWeek = "week"; case thisMonth = "month"
        case totalTrips = "total_trips"; case totalEarned = "total_earned"; case avgPerTrip = "avg_per_trip"
    }
    // Numeric helpers for display
    var todayNum:      Double { parse(today) }
    var totalEarnedNum:Double { parse(totalEarned) }
    private func parse(_ s: String?) -> Double { Double(s?.replacingOccurrences(of:"R", with:"") ?? "0") ?? 0 }
}
struct EarningsResponse: Decodable { let success: Bool; let earnings: BEEarnings }

// MARK: - Trip request overlay model (driver receives)
struct TripRequestItem: Identifiable {
    let id = UUID()
    let tripId: String; let pickup: String; let dropoff: String
    let fare: Double; let rideType: String
    var isCustom: Bool { rideType == "custom" }
}

// MARK: - Popular destinations
struct PopularPlace: Identifiable {
    let id = UUID()
    let name: String; let address: String; let emoji: String
    let lat: Double;  let lon: Double
    static let all: [PopularPlace] = [
        .init(name: "OR Tambo Airport",  address: "OR Tambo International Airport, Ekurhuleni", emoji: "✈️", lat: -26.1392, lon: 28.2460),
        .init(name: "Sandton City",      address: "Sandton City Mall, Sandton",                  emoji: "🛒", lat: -26.1073, lon: 28.0564),
        .init(name: "Waterfall City",    address: "Waterfall City, Midrand",                     emoji: "🏙", lat: -25.9989, lon: 28.1121),
        .init(name: "Mall of Africa",    address: "Mall of Africa, Midrand",                     emoji: "🛍", lat: -26.0000, lon: 28.1141),
        .init(name: "Rosebank",          address: "Rosebank Mall, Rosebank, Johannesburg",       emoji: "☕️", lat: -26.1467, lon: 28.0425),
        .init(name: "Menlyn Park",       address: "Menlyn Park Shopping Centre, Pretoria",       emoji: "🏬", lat: -25.7826, lon: 28.2767),
    ]
}
