import Foundation
import CoreLocation

// MARK: - Trip Service (passenger + driver)
final class TripService {
    static let shared = TripService()
    private let api = APIClient.shared
    private init() {}

    // MARK: Passenger
    func loadServices() async throws -> [BEServiceCategory] {
        let r: ServicesResponse = try await api.request("/services")
        return r.categories
    }

    func estimate(serviceKey: String, pickup: CLLocationCoordinate2D,
                  dropoff: CLLocationCoordinate2D) async throws -> EstimateResponse {
        try await api.request("/services/estimate", method: .POST, body: [
            "serviceKey": serviceKey,
            "pickupLat":  pickup.latitude,  "pickupLon":  pickup.longitude,
            "dropoffLat": dropoff.latitude, "dropoffLon": dropoff.longitude
        ])
    }

    func requestTrip(rideType: String, serviceKey: String,
                     pickupAddr: String,  pickup:  CLLocationCoordinate2D,
                     dropoffAddr: String, dropoff: CLLocationCoordinate2D,
                     payment: String = "cash",
                     scheduledAt: String? = nil,
                     hireHours: Int? = nil) async throws -> BETrip {
        var body: [String: Any] = [
            "rideType": rideType, "serviceKey": serviceKey,
            "pickupAddress":  pickupAddr,  "pickupLat":  pickup.latitude,  "pickupLon":  pickup.longitude,
            "dropoffAddress": dropoffAddr, "dropoffLat": dropoff.latitude, "dropoffLon": dropoff.longitude,
            "paymentMethod": payment
        ]
        if let s = scheduledAt { body["scheduledAt"] = s }
        if let h = hireHours   { body["hireHours"]   = h }
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

    func rateTrip(_ id: String, rating: Int, comment: String? = nil) async throws {
        var body: [String: Any] = ["rating": rating]
        if let c = comment { body["comment"] = c }
        let _: SuccessMsg = try await api.request("/trips/\(id)/rate", method: .POST, body: body)
    }

    func myTrips() async throws -> [BETrip] {
        let r: TripListResponse = try await api.request("/trips/my?limit=20")
        return r.trips
    }

    func savePreference(_ pref: String) async throws {
        let _: SuccessMsg = try await api.request(
            "/trips/service-preference", method: .POST, body: ["preference": pref])
    }

    // MARK: Driver
    func acceptTrip(_ id: String) async throws -> BETrip {
        let r: TripSingleResponse = try await api.request("/trips/\(id)/accept", method: .POST)
        return r.trip
    }

    func driverArrived(_ id: String) async throws -> BETrip {
        let r: TripSingleResponse = try await api.request("/trips/\(id)/arrived", method: .POST)
        return r.trip
    }

    func startTrip(_ id: String) async throws -> BETrip {
        let r: TripSingleResponse = try await api.request("/trips/\(id)/start", method: .POST)
        return r.trip
    }

    func completeTrip(_ id: String, distKm: Double? = nil, durMin: Int? = nil) async throws -> BETrip {
        var body: [String: Any] = [:]
        if let d = distKm { body["actualDistanceKm"]  = d }
        if let m = durMin  { body["actualDurationMin"] = m }
        let r: TripSingleResponse = try await api.request("/trips/\(id)/complete", method: .POST, body: body)
        return r.trip
    }
}

// MARK: - Driver Service
final class DriverService {
    static let shared = DriverService()
    private let api = APIClient.shared
    private init() {}

    func getProfile() async throws -> BEDriverProfile {
        let r: DriverProfileResponse = try await api.request("/drivers/profile")
        return r.profile
    }

    func goOnline() async throws {
        let _: SuccessMsg = try await api.request("/drivers/go-online", method: .POST)
    }

    func goOffline() async throws {
        let _: SuccessMsg = try await api.request("/drivers/go-offline", method: .POST)
    }

    func updateLocation(lat: Double, lon: Double) async throws {
        let _: SuccessMsg = try await api.request(
            "/drivers/location", method: .POST, body: ["lat": lat, "lon": lon])
    }

    func getEarnings() async throws -> BEEarnings {
        let r: EarningsResponse = try await api.request("/drivers/earnings")
        return r.earnings
    }

    func driverTrips() async throws -> [BETrip] {
        let r: TripListResponse = try await api.request("/trips/my?limit=20")
        return r.trips
    }
}
