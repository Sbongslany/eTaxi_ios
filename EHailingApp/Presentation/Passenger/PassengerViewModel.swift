import SwiftUI
import MapKit
import Combine

enum PScreen: Equatable {
    case serviceChoice, home, booking, findingDriver, inRide, tripComplete
    case customHire, hireConfirmed, history, wallet, profile
}

private enum PTrip {
    static var id: String? {
        get { UserDefaults.standard.string(forKey: "p_trip_id") }
        set { UserDefaults.standard.set(newValue, forKey: "p_trip_id") }
    }
    static func clear() { id = nil }
}

@MainActor
final class PassengerViewModel: ObservableObject {
    @Published var screen:       PScreen = .serviceChoice
    @Published var selectedTab:  Int = 0
    let user: UserEntity

    // Location
    @Published var pickupCoord:    CLLocationCoordinate2D?
    @Published var pickupAddress:  String = ""
    @Published var dropoffCoord:   CLLocationCoordinate2D?
    @Published var dropoffAddress: String = ""
    @Published var driverCoord:    CLLocationCoordinate2D?

    // Map bindings (shared across screens)
    @Published var mapEta:      String = "—"
    @Published var mapDist:     String = "—"
    @Published var mapTraffic:  TrafficLevel = .unknown

    // Services
    @Published var categories:       [BEServiceCategory] = []
    @Published var standardServices: [BERideService]     = []
    @Published var selectedService:  BERideService?
    @Published var estimates:        [String: EstimateResponse] = [:]
    @Published var servicesLoaded    = false

    // Trip
    @Published var currentTrip:   BETrip?
    @Published var searchTimedOut = false
    @Published var searchSeconds  = 60
    @Published var isLoading      = false
    @Published var errorMessage:  String?

    // Rating
    @Published var selectedRating: Int = 5
    @Published var ratingTags:     Set<String> = []
    @Published var ratingComment:  String = ""

    // History
    @Published var tripHistory: [BETrip] = []

    // Hire
    @Published var hireDate:     Date   = Date().addingTimeInterval(3600)
    @Published var hireDuration: String = "hourly"
    @Published var hireHours:    Int    = 1

    private let trips = TripService.shared
    private let ws    = WebSocketManager.shared
    private var pollTask:    Task<Void, Never>?
    private var searchTimer: Timer?
    private var wsSub:       AnyCancellable?
    private var locSubs      = Set<AnyCancellable>()

    init(user: UserEntity) {
        self.user = user
        if UserDefaults.standard.string(forKey: "svc_pref_\(user.id)") != nil { screen = .home }
        setupLocation(); setupWS()
        Task { await restoreSession() }
    }

    private func setupLocation() {
        let loc = LocationManager.shared
        loc.$coordinate.sink { [weak self] c in
            guard let self, let c else { return }
            // Always keep pickupCoord current unless passenger has manually changed it
            self.pickupCoord = c
        }.store(in: &locSubs)
        loc.$address.sink { [weak self] a in
            guard let self, !a.isEmpty, a != "Getting location..." else { return }
            self.pickupAddress = a
        }.store(in: &locSubs)
    }

    func syncPickup() {
        let loc = LocationManager.shared
        if let c = loc.coordinate {
            pickupCoord   = c
            pickupAddress = loc.address.isEmpty ? "Current Location" : loc.address
        }
    }

    private func setupWS() {
        ws.connect()
        wsSub = ws.events.receive(on: RunLoop.main).sink { [weak self] ev in
            guard let self else { return }
            switch ev {
            case .driverLocation(let lat, let lon):
                self.driverCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            case .tripStatusChanged(let tid, let st):
                guard self.currentTrip?.id == tid else { return }
                self.currentTrip?.status = st
                self.route(to: st)
            default: break
            }
        }
    }

    private func route(to status: String) {
        switch status {
        case "accepted","driver_en_route","driver_arrived":
            if screen != .findingDriver { screen = .findingDriver }
        case "in_progress":
            screen = .inRide; stopTimer()
        case "completed":
            PTrip.clear(); screen = .tripComplete; stopPoll(); stopTimer()
        case "no_driver_found":
            // Show retry screen instead of going home
            searchTimedOut = true
            stopPoll(); stopTimer()
            PTrip.clear()
        default:
            if status.contains("cancelled") {
                PTrip.clear(); currentTrip = nil; driverCoord = nil; stopPoll(); stopTimer(); screen = .home
            }
        }
    }

    private func restoreSession() async {
        guard let id = PTrip.id, let trip = try? await trips.getTrip(id) else {
            PTrip.clear(); return
        }
        currentTrip = trip
        switch trip.status {
        case "searching","accepted","driver_en_route","driver_arrived":
            screen = .findingDriver; startPoll(id: id); startTimer()
        case "in_progress":
            screen = .inRide; startPoll(id: id)
        default: PTrip.clear(); screen = .home
        }
    }

    // MARK: Preference
    func selectPreference(_ pref: String) {
        UserDefaults.standard.set(pref, forKey: "svc_pref_\(user.id)")
        Task { try? await trips.savePreference(pref) }
        screen = .home
    }

    // MARK: Services
    func loadServices() async {
        guard !servicesLoaded else { return }
        guard let cats = try? await trips.loadServices() else { return }
        categories       = cats
        standardServices = cats.flatMap { $0.services }.filter { $0.isStandard }
        selectedService  = selectedService ?? standardServices.first
        servicesLoaded   = true
    }

    // MARK: Destination
    func setDestination(_ address: String, coord: CLLocationCoordinate2D) {
        dropoffAddress = address; dropoffCoord = coord
        Task { await fetchEstimates() }
    }

    func setPopular(_ p: PopularPlace) {
        setDestination(p.address, coord: .init(latitude: p.lat, longitude: p.lon))
    }

    func fetchEstimates() async {
        guard let pickup = pickupCoord, let dropoff = dropoffCoord else { return }
        await withTaskGroup(of: Void.self) { g in
            for svc in standardServices {
                g.addTask { [weak self] in
                    guard let self else { return }
                    if let r = try? await self.trips.estimate(serviceKey: svc.key, pickup: pickup, dropoff: dropoff) {
                        await MainActor.run { self.estimates[svc.key] = r }
                    }
                }
            }
        }
    }

    var selectedFare: Double? {
        guard let key = selectedService?.key, let e = estimates[key] else { return nil }
        return e.estimated ?? e.min
    }
    var confirmTitle: String { selectedFare.map { "Confirm · R\(Int($0))" } ?? "Confirm" }

    // MARK: Request ride
    func confirmRide() {
        // Always use freshest GPS
        let liveCoord = LocationManager.shared.coordinate
        let liveAddr  = LocationManager.shared.address

        let pickup = liveCoord ?? pickupCoord
        let addr   = (liveCoord != nil && !liveAddr.isEmpty && liveAddr != "Getting location...") ? liveAddr : pickupAddress

        guard let pickup, !addr.isEmpty,
              let dropoff = dropoffCoord, !dropoffAddress.isEmpty else {
            errorMessage = "Please select a destination"; return
        }
        if let live = liveCoord { pickupCoord = live; pickupAddress = liveAddr }

        let svc = selectedService
        Task {
            isLoading = true; errorMessage = nil; defer { isLoading = false }
            do {
                let key = svc?.key ?? "standard"
                print("[Passenger] Requesting trip: pickup=\(pickup.latitude),\(pickup.longitude) dropoff=\(dropoff.latitude),\(dropoff.longitude) rideType=\(key)")
                currentTrip = try await trips.requestTrip(
                    rideType: key, serviceKey: key,
                    pickupAddr: addr, pickup: pickup,
                    dropoffAddr: dropoffAddress, dropoff: dropoff)
                PTrip.id = currentTrip?.id
                searchTimedOut = false
                screen = .findingDriver
                if let id = currentTrip?.id { startPoll(id: id); startTimer() }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    // MARK: Custom hire
    var hireDurationHours: Int {
        switch hireDuration { case "halfday": return 4; case "fullday": return 8; case "weekend": return 16; default: return max(1, hireHours) }
    }
    var hireEstimatedFare: Double {
        let rate = categories.flatMap { $0.services }.first { $0.isCustomHire }?.perHour ?? 150
        return rate * Double(hireDurationHours)
    }

    func confirmHire() {
        guard let pickup = pickupCoord else { errorMessage = "Set pickup location"; return }
        let dropoff  = dropoffCoord ?? pickup
        let dropAddr = dropoffAddress.isEmpty ? pickupAddress : dropoffAddress
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime]
        Task {
            isLoading = true; errorMessage = nil; defer { isLoading = false }
            do {
                currentTrip = try await trips.requestTrip(
                    rideType: "custom", serviceKey: "custom_hire",
                    pickupAddr: pickupAddress, pickup: pickup,
                    dropoffAddr: dropAddr, dropoff: dropoff,
                    scheduledAt: iso.string(from: hireDate), hireHours: hireDurationHours)
                screen = .hireConfirmed
            } catch { errorMessage = error.localizedDescription }
        }
    }

    // MARK: Cancel
    func cancelRide() {
        let id = currentTrip?.id
        stopPoll(); stopTimer()
        currentTrip = nil; driverCoord = nil; searchTimedOut = false; PTrip.clear(); screen = .home
        if let id { Task.detached { try? await TripService.shared.cancelTrip(id, reason: "Passenger cancelled") } }
    }
    func retryRide()       { searchTimedOut = false; confirmRide() }
    func dismissNoDriver() { searchTimedOut = false; currentTrip = nil; screen = .home }

    // MARK: Rating
    func submitRating() {
        guard let id = currentTrip?.id else { goHome(); return }
        Task { try? await trips.rateTrip(id, rating: selectedRating, comment: ratingComment.isEmpty ? nil : ratingComment); goHome() }
    }

    // MARK: History
    func loadHistory() async { tripHistory = (try? await trips.myTrips()) ?? [] }

    // MARK: Go home
    func goHome() {
        stopPoll(); stopTimer()
        currentTrip = nil; driverCoord = nil
        dropoffCoord = nil; dropoffAddress = ""; estimates = [:]
        selectedRating = 5; ratingTags = Set<String>(); ratingComment = ""
        screen = .home; selectedTab = 0
    }

    // MARK: Polling (2s like ZipRide)
    private func startPoll(id: String) {
        pollTask?.cancel()
        let t0 = Date()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self else { return }
                // 120s client-side timeout
                if await self.currentTrip?.status == "searching",
                   Date().timeIntervalSince(t0) >= 120 {
                    await MainActor.run { self.searchTimedOut = true; self.currentTrip = nil }
                    Task.detached { try? await TripService.shared.cancelTrip(id, reason: "timeout") }
                    return
                }
                guard let trip = try? await TripService.shared.getTrip(id) else { continue }
                print("[Poll] trip status: \(trip.status)")
                await MainActor.run { self.currentTrip = trip; self.route(to: trip.status) }
                if ["completed","cancelled_passenger","cancelled_driver","cancelled_system"].contains(trip.status) { return }
                // no_driver_found: don't give up immediately — stay searching
                // The backend marks no_driver_found fast but we can keep showing
                // the finding screen and let user retry manually
                if trip.status == "no_driver_found" { return }
            }
        }
    }
    private func stopPoll() { pollTask?.cancel(); pollTask = nil }
    private func startTimer() {
        searchSeconds = 120; searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in guard let self else { return }; if self.searchSeconds > 0 { self.searchSeconds -= 1 } }
        }
    }
    private func stopTimer() { searchTimer?.invalidate(); searchTimer = nil }

    // Home screen nearby pins
    var nearbyPins: [ENearbyPin] {
        guard let c = LocationManager.shared.coordinate else { return [] }
        return [
            ENearbyPin(coord: .init(latitude: c.latitude + 0.006, longitude: c.longitude - 0.005)),
            ENearbyPin(coord: .init(latitude: c.latitude - 0.004, longitude: c.longitude + 0.007)),
            ENearbyPin(coord: .init(latitude: c.latitude + 0.003, longitude: c.longitude + 0.009)),
        ]
    }
}
