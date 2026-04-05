import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - LocationManager
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let mgr      = CLLocationManager()
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var address:    String = "Getting location..."
    @Published var authorized  = false
    @Published var accuracy:   CLLocationAccuracy = 999

    override init() {
        super.init()
        mgr.delegate                           = self
        mgr.desiredAccuracy                    = kCLLocationAccuracyBestForNavigation
        mgr.distanceFilter                     = 8
        mgr.pausesLocationUpdatesAutomatically = false
        print("[LocationManager] init — status: \(mgr.authorizationStatus.rawValue)")
        // Always request - if already authorised, iOS calls delegate immediately
        mgr.requestWhenInUseAuthorization()
        // If already authorised, start immediately (delegate may not fire again)
        let s = mgr.authorizationStatus
        if s == .authorizedWhenInUse || s == .authorizedAlways {
            print("[LocationManager] already authorised — starting immediately")
            mgr.startUpdatingLocation()
        }
    }

    func start() {
        print("[LocationManager] start() called — status: \(mgr.authorizationStatus.rawValue)")
        mgr.startUpdatingLocation()
    }
    func stop()  { mgr.stopUpdatingLocation() }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        print("[LocationManager] auth changed — status: \(m.authorizationStatus.rawValue)")
        switch m.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authorized = true
            m.startUpdatingLocation()
        default:
            authorized = false
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }
        print("[LocationManager] Got location: \(loc.coordinate.latitude), \(loc.coordinate.longitude), accuracy: \(loc.horizontalAccuracy)")
        DispatchQueue.main.async {
            self.coordinate = loc.coordinate
            self.accuracy   = loc.horizontalAccuracy
        }
        // Geocode even with lower accuracy so address updates sooner
        reverseGeocode(loc)
    }

    private func reverseGeocode(_ loc: CLLocation) {
        Task { [weak self] in
            guard let self else { return }
            do {
                // async/await variant is NOT deprecated on iOS 26
                let placemarks = try await CLGeocoder().reverseGeocodeLocation(loc)
                guard let p = placemarks.first else { return }
                var parts: [String] = []
                if let n = p.subThoroughfare, let s = p.thoroughfare { parts.append("\(n) \(s)") }
                else if let s = p.thoroughfare { parts.append(s) }
                if let sub = p.subLocality    { parts.append(sub)  }
                else if let city = p.locality { parts.append(city) }
                let result = parts.isEmpty ? "Current Location" : parts.joined(separator: ", ")
                await MainActor.run { self.address = result }
            } catch {}
        }
    }
}


extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - Nearby pins



struct ENearbyPin: Identifiable {
    let id    = UUID()
    let coord: CLLocationCoordinate2D
}

// MARK: - EHomeMap (home screen — zooms tight to user location)
struct EHomeMap: UIViewRepresentable {
    var nearbyPins: [ENearbyPin]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate              = context.coordinator
        map.showsUserLocation     = true
        map.showsCompass          = true
        map.showsTraffic          = false
        map.pointOfInterestFilter = .includingAll
        // Start following user immediately
        map.setUserTrackingMode(.follow, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // If user hasn't interacted, keep following
        if map.userTrackingMode == .none {
            map.setUserTrackingMode(.follow, animated: true)
        }
        // Add nearby driver pins if changed
        let existing = map.annotations.filter { !($0 is MKUserLocation) }
        guard existing.count != nearbyPins.count else { return }
        map.removeAnnotations(existing)
        nearbyPins.forEach { p in
            let a = MKPointAnnotation()
            a.coordinate = p.coord
            a.title = "Driver"
            map.addAnnotation(a)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private var initialZoomDone = false

        func mapView(_ m: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard !initialZoomDone, userLocation.location?.horizontalAccuracy ?? 999 < 500 else { return }
            initialZoomDone = true
            // Zoom to street level on first accurate fix
            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008))
            m.setRegion(region, animated: true)
        }

        func mapView(_ m: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let id = "car"
            let v  = m.dequeueReusableAnnotationView(withIdentifier: id)
                     ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            v.annotation = annotation
            v.image = UIImage(systemName: "car.fill")?.withTintColor(
                UIColor(red: 0, green: 0.898, blue: 0.455, alpha: 1),
                renderingMode: .alwaysOriginal)
            v.frame = CGRect(x: 0, y: 0, width: 28, height: 28)
            return v
        }
    }
}


// geocode() defined in DriverViews.swift
