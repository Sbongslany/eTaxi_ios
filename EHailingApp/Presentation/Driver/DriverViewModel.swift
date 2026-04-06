import SwiftUI
import MapKit
import Combine

enum DScreen: Equatable {
    case home, enRoute, arrived, activeTrip, tripComplete, trips, earnings, profile
}

private enum DTrip {
    static var id: String? {
        get { UserDefaults.standard.string(forKey: "d_trip_id") }
        set { UserDefaults.standard.set(newValue, forKey: "d_trip_id") }
    }
    static func clear() { id = nil }
}

@MainActor
final class DriverViewModel: ObservableObject {
    @Published var screen:       DScreen = .home
    @Published var selectedTab:  Int = 0
    let user: UserEntity

    // Status
    @Published var isOnline:     Bool = false
    @Published var isLoading:    Bool = false
    @Published var errorMessage: String?

    // Profile
    @Published var profile: BEDriverProfile?

    // Trip
    @Published var currentTrip:    BETrip?
    @Published var pendingRequest: TripRequestItem?
    @Published var hasPending      = false

    // Map bindings
    @Published var mapEta:      String = "—"
    @Published var mapDist:     String = "—"
    @Published var mapTraffic:  TrafficLevel = .unknown
    @Published var driverCoord: CLLocationCoordinate2D?

    // History + earnings
    @Published var tripHistory: [BETrip] = []
    @Published var earnings:    BEEarnings?

    private let trips    = TripService.shared
    private let drvSvc   = DriverService.shared
    private let ws       = WebSocketManager.shared
    private var wsSub:       AnyCancellable?
    private var locTimer:    Timer?
    private var pollTask:    Task<Void, Never>?
    private var locSubs      = Set<AnyCancellable>()

    init(user: UserEntity) {
        self.user = user
        setupWS()
        setupLocation()
        Task { await loadProfile(); await restoreSession() }
    }

    private func setupLocation() {
        let loc = LocationManager.shared
        loc.start()  // ensure location is running for driver
        loc.$coordinate.sink { [weak self] c in self?.driverCoord = c }.store(in: &locSubs)
    }

    private func setupWS() {
        ws.connect()
        wsSub = ws.events.receive(on: RunLoop.main).sink { [weak self] ev in
            guard let self else { return }
            switch ev {
            case .connected:
                if self.isOnline { self.ws.subscribeDriver() }
            case .tripRequest(let tid, let pickup, let dropoff, let fare, let rt):
                let req = TripRequestItem(tripId: tid, pickup: pickup, dropoff: dropoff, fare: fare, rideType: rt)
                self.pendingRequest = req
                withAnimation(.spring(response: 0.4)) { self.hasPending = true }
            case .tripStatusChanged(let tid, let st):
                // If this trip is the PENDING request and it got cancelled → dismiss overlay
                if self.pendingRequest?.tripId == tid {
                    let wasCancelled = st.contains("cancelled") || st == "no_driver_found"
                    if wasCancelled {
                        withAnimation(.spring(response: 0.4)) {
                            self.hasPending = false; self.pendingRequest = nil
                        }
                        return  // Nothing more to do — trip is gone
                    }
                    // Don't handle "accepted" here — acceptTrip() handles it
                    // Avoids race where WS clears overlay before acceptTrip Task finishes
                }
                // Update already-accepted active trip
                guard self.currentTrip?.id == tid else { return }
                self.currentTrip?.status = st
                self.driverRoute(to: st)
            default: break
            }
        }
    }

    private func driverRoute(to status: String) {
        switch status {
        case "accepted", "driver_en_route":
            if screen != .enRoute { screen = .enRoute }
        case "driver_arrived":
            if screen != .arrived { screen = .arrived }
        case "in_progress":
            if screen != .activeTrip { screen = .activeTrip }
        case "completed":
            DTrip.clear(); stopPoll(); currentTrip = nil; screen = .tripComplete
        default:
            if status.contains("cancelled") || status == "no_driver_found" {
                currentTrip = nil; DTrip.clear(); stopPoll()
                withAnimation(.spring(response: 0.4)) {
                    hasPending = false; pendingRequest = nil; screen = .home
                }
            }
        }
    }

    private func restoreSession() async {
        guard let id = DTrip.id, let trip = try? await trips.getTrip(id) else { DTrip.clear(); return }
        currentTrip = trip
        switch trip.status {
        case "accepted","driver_en_route": screen = .enRoute; startPoll(id: id)
        case "driver_arrived":             screen = .arrived; startPoll(id: id)
        case "in_progress":                screen = .activeTrip; startPoll(id: id)
        default: DTrip.clear(); screen = .home
        }
    }

    // MARK: Online / Offline
    func goOnline() {
        Task {
            isLoading = true; defer { isLoading = false }
            do {
                // Wait up to 8 seconds for a valid GPS fix before going online
                var coord = LocationManager.shared.coordinate
                if coord == nil {
                    for _ in 0..<8 {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        coord = LocationManager.shared.coordinate
                        if coord != nil { break }
                    }
                }
                // Send location BEFORE going online so backend query finds us
                if let coord {
                    try? await drvSvc.updateLocation(lat: coord.latitude, lon: coord.longitude)
                    print("[Driver] Sent location before goOnline: \(coord.latitude), \(coord.longitude)")
                } else {
                    print("[Driver] WARNING: No location available when going online")
                }
                try await drvSvc.goOnline()
                withAnimation(.spring(response: 0.4)) { isOnline = true }
                ws.subscribeDriver()
                startLocationBroadcast()
            } catch {
                // Show the real error — e.g. "All required SA documents must be verified"
                errorMessage = error.localizedDescription
                print("[Driver] goOnline failed: \(error.localizedDescription)")
            }
        }
    }

    func goOffline() {
        Task {
            isLoading = true; defer { isLoading = false }
            do {
                try await drvSvc.goOffline()
                withAnimation(.spring(response: 0.4)) { isOnline = false }
                stopLocationBroadcast()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    // MARK: Trip accept / decline
    func acceptTrip() {
        guard let req = pendingRequest else { return }
        Task {
            isLoading = true; defer { isLoading = false }
            do {
                let trip = try await trips.acceptTrip(req.tripId)
                currentTrip = trip; DTrip.id = trip.id
                withAnimation { hasPending = false; pendingRequest = nil }
                screen = .enRoute; startPoll(id: trip.id)
            } catch {
                // Trip was cancelled before we could accept — clear overlay gracefully
                print("[Driver] acceptTrip failed (likely cancelled): \(error.localizedDescription)")
                withAnimation(.spring(response: 0.4)) {
                    hasPending = false; pendingRequest = nil
                }
                // Don't show error message for cancelled trips — just silently return to home
                let msg = error.localizedDescription.lowercased()
                if !msg.contains("cancel") && !msg.contains("not found") && !msg.contains("404") {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func declineTrip() {
        if let req = pendingRequest { ws.declineTrip(req.tripId) }
        withAnimation { hasPending = false; pendingRequest = nil }
    }

    // MARK: Driver trip actions
    func markArrived() {
        guard let id = currentTrip?.id else { return }
        Task {
            currentTrip = try? await trips.driverArrived(id)
            screen = .arrived
        }
    }

    func startRide() {
        guard let id = currentTrip?.id else { return }
        Task {
            currentTrip = try? await trips.startTrip(id)
            screen = .activeTrip
        }
    }

    func completeRide() {
        guard let id = currentTrip?.id else { return }
        Task {
            if let completed = try? await trips.completeTrip(id) { currentTrip = completed }
            DTrip.clear(); stopPoll()
            screen = .tripComplete
        }
    }

    func triggerPanic(lat: Double, lon: Double) async {
        print("[Driver] SOS triggered at \(lat), \(lon)")
        // TODO: call backend panic endpoint
    }

    func dismissTripComplete() {
        currentTrip = nil; screen = .home
    }

    // MARK: Profile
    func loadProfile() async {
        profile = try? await drvSvc.getProfile()
        if let p = profile { isOnline = p.isOnline }
    }

    // MARK: History + Earnings
    func loadHistory()  async { tripHistory = (try? await drvSvc.driverTrips()) ?? [] }
    func loadEarnings() async { earnings    = try? await drvSvc.getEarnings() }

    // MARK: Polling
    private func startPoll(id: String) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self else { return }
                do {
                    let trip = try await TripService.shared.getTrip(id)
                    await MainActor.run {
                        self.currentTrip = trip
                        self.driverRoute(to: trip.status)
                    }
                    let terminal = ["completed","cancelled_passenger","cancelled_driver",
                                    "cancelled_system","no_driver_found"]
                    if terminal.contains(trip.status) { return }
                } catch {
                    // Trip fetch failed — if driver is on a trip screen, return home safely
                    await MainActor.run {
                        if self.screen != .home {
                            let statusCode = (error as NSError).code
                            if statusCode == 404 {
                                // Trip not found — cancelled
                                self.currentTrip = nil; DTrip.clear()
                                withAnimation { self.screen = .home }
                                print("[Driver] Trip not found (404) — returning home")
                            }
                        }
                    }
                    // Continue polling for non-fatal errors
                }
            }
        }
    }
    private func stopPoll() { pollTask?.cancel(); pollTask = nil }

    // MARK: Location broadcast (every 5s when online)
    private func startLocationBroadcast() {
        locTimer?.invalidate()
        LocationManager.shared.start()
        // Send immediately if we have location
        if let coord = LocationManager.shared.coordinate {
            ws.sendLocation(lat: coord.latitude, lon: coord.longitude)
            Task { try? await DriverService.shared.updateLocation(lat: coord.latitude, lon: coord.longitude) }
        }
        // Update every 3 seconds
        locTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self, let coord = LocationManager.shared.coordinate else { return }
            self.ws.sendLocation(lat: coord.latitude, lon: coord.longitude)
            Task {
                try? await DriverService.shared.updateLocation(lat: coord.latitude, lon: coord.longitude)
                print("[Driver] Location broadcast: \(coord.latitude), \(coord.longitude)")
            }
        }
    }
    private func stopLocationBroadcast() { locTimer?.invalidate(); locTimer = nil }
}
