import Foundation
import CoreLocation

// MARK: - TripAPI
// This file replaces the old TripAPI that used Trip/ServiceCategory/SuccessResponse.
// All types now come from TripModels.swift (BETrip, BERideService, etc.)
// TripService.swift (in the same folder) contains the same calls — both are valid.

final class TripAPI {
    static let shared = TripAPI()
    private let api = APIClient.shared
    private init() {}

    // MARK: - Services
    func loadServices() async throws -> [BEServiceCategory] {
        let r: ServicesResponse = try await api.request("/services")
        return r.categories
    }

    func estimateForService(serviceKey: String,
                            pickup:  CLLocationCoordinate2D,
                            dropoff: CLLocationCoordinate2D) async throws -> EstimateResponse {
        try await api.request("/services/estimate", method: .POST, body: [
            "serviceKey": serviceKey,
            "pickupLat":  pickup.latitude,  "pickupLon":  pickup.longitude,
            "dropoffLat": dropoff.latitude, "dropoffLon": dropoff.longitude
        ])
    }

    // MARK: - Trips
    func requestTrip(rideType: String, serviceKey: String,
                     pickupAddr:  String, pickup:  CLLocationCoordinate2D,
                     dropoffAddr: String, dropoff: CLLocationCoordinate2D,
                     payment: String = "cash",
                     scheduledAt: String? = nil,
                     hireHours: Int? = nil, hireDays: Int? = nil) async throws -> BETrip {
        var body: [String: Any] = [
            "rideType": rideType, "serviceKey": serviceKey,
            "pickupAddress":  pickupAddr,  "pickupLat":  pickup.latitude,  "pickupLon":  pickup.longitude,
            "dropoffAddress": dropoffAddr, "dropoffLat": dropoff.latitude, "dropoffLon": dropoff.longitude,
            "paymentMethod": payment
        ]
        if let s = scheduledAt { body["scheduledAt"] = s }
        if let h = hireHours   { body["hireHours"]   = h }
        if let d = hireDays    { body["hireDays"]     = d }
        let r: TripSingleResponse = try await api.request("/trips/request", method: .POST, body: body)
        return r.trip
    }

    func getTrip(_ id: String) async throws -> BETrip {
        let r: TripSingleResponse = try await api.request("/trips/\(id)")
        return r.trip
    }

    func cancelTrip(_ id: String, reason: String? = nil) async throws {
        var body: [String: Any] = [:]
        if let r = reason { body["reason"] = r }
        let _: SuccessMsg = try await api.request("/trips/\(id)/cancel", method: .POST, body: body)
    }

    func myTrips() async throws -> [BETrip] {
        let r: TripListResponse = try await api.request("/trips/my?limit=20")
        return r.trips
    }

    func rateTrip(_ id: String, rating: Int, comment: String? = nil) async throws {
        var body: [String: Any] = ["rating": rating]
        if let c = comment { body["comment"] = c }
        let _: SuccessMsg = try await api.request("/trips/\(id)/rate", method: .POST, body: body)
    }

    func saveServicePreference(_ pref: String) async throws {
        let _: SuccessMsg = try await api.request(
            "/trips/service-preference", method: .POST, body: ["preference": pref])
    }
}
