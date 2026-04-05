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

// MARK: - Traffic
enum TrafficLevel: Equatable { case clear, moderate, heavy, unknown }

final class TrafficPolyline: MKPolyline {
    var trafficLevel: TrafficLevel = .clear
    var isAlternate: Bool = false
    convenience init(points: UnsafePointer<MKMapPoint>, count: Int, level: TrafficLevel, alt: Bool) {
        self.init(points: points, count: count)
        trafficLevel = level
        isAlternate  = alt
    }
}

// MARK: - ETaxiMap
struct ETaxiMap: UIViewRepresentable {
    var origin:     CLLocationCoordinate2D?
    var target:     CLLocationCoordinate2D?
    var isPickup:   Bool = true
    var fitRoute:   Bool = true
    var followUser: Bool = false

    @Binding var eta:      String
    @Binding var distance: String
    @Binding var traffic:  TrafficLevel

    func makeUIView(context: Context) -> MKMapView {
        let m = MKMapView()
        m.delegate          = context.coordinator
        m.showsUserLocation = true
        m.showsCompass      = false
        m.showsTraffic      = true
        m.userTrackingMode  = followUser ? .follow : .none
        return m
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        guard let target else { return }
        let co = context.coordinator
        let moved: (CLLocationCoordinate2D?, CLLocationCoordinate2D?, Double) -> Bool = { a, b, t in
            guard let a, let b else { return b != nil }
            return CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude)) > t
        }
        guard moved(co.lastTarget, target, 20) || moved(co.lastOrigin, origin, 50) else { return }
        co.lastTarget = target
        co.lastOrigin = origin
        co.draw(map: map, from: origin, to: target, isPickup: isPickup, fit: fitRoute,
                eta: $eta, dist: $distance, traffic: $traffic)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var lastTarget: CLLocationCoordinate2D?
        var lastOrigin: CLLocationCoordinate2D?
        private var routing = false

        func draw(map: MKMapView,
                  from origin: CLLocationCoordinate2D?,
                  to target: CLLocationCoordinate2D,
                  isPickup: Bool, fit: Bool,
                  eta: Binding<String>, dist: Binding<String>,
                  traffic: Binding<TrafficLevel>) {
            guard !routing else { return }
            routing = true
            map.removeOverlays(map.overlays)
            map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })

            let pin = MKPointAnnotation()
            pin.coordinate = target
            pin.title      = isPickup ? "Pickup" : "Drop-off"
            map.addAnnotation(pin)

            if let o = origin {
                let dp = MKPointAnnotation()
                dp.coordinate = o
                dp.title      = "Driver"
                map.addAnnotation(dp)
            }

            let req = MKDirections.Request()
            req.transportType           = .automobile
            req.requestsAlternateRoutes = true
            req.departureDate           = Date()
            req.destination = MKMapItem(placemark: MKPlacemark(coordinate: target))
            req.source      = origin.map { MKMapItem(placemark: MKPlacemark(coordinate: $0)) }
                              ?? MKMapItem.forCurrentLocation()

            MKDirections(request: req).calculate { [weak self] resp, _ in
                guard let self else { return }
                self.routing = false
                DispatchQueue.main.async {
                    guard let routes = resp?.routes, !routes.isEmpty else {
                        if let o = origin {
                            map.addOverlay(MKPolyline(coordinates: [o, target], count: 2))
                        }
                        eta.wrappedValue     = "--"
                        dist.wrappedValue    = "--"
                        traffic.wrappedValue = .unknown
                        return
                    }
                    let best = routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime })!
                    let tl   = self.trafficFor(best)

                    for r in routes where r !== best {
                        map.addOverlay(
                            TrafficPolyline(points: r.polyline.points(),
                                            count: r.polyline.pointCount,
                                            level: .unknown, alt: true),
                            level: .aboveRoads)
                    }
                    map.addOverlay(
                        TrafficPolyline(points: best.polyline.points(),
                                        count: best.polyline.pointCount,
                                        level: tl, alt: false),
                        level: .aboveRoads)

                    if fit {
                        map.setVisibleMapRect(
                            best.polyline.boundingMapRect,
                            edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 380, right: 40),
                            animated: true)
                    }

                    let mins = Int(best.expectedTravelTime / 60)
                    eta.wrappedValue  = mins <= 0 ? "< 1 min" : "\(mins) min"
                    let km = best.distance / 1000
                    dist.wrappedValue = km < 1
                        ? "\(Int(best.distance)) m"
                        : String(format: "%.1f km", km)
                    traffic.wrappedValue = tl
                }
            }
        }

        private func trafficFor(_ r: MKRoute) -> TrafficLevel {
            let ratio = r.expectedTravelTime / max(r.distance / 13.9, 1)
            if ratio > 2.0  { return .heavy }
            if ratio > 1.35 { return .moderate }
            return .clear
        }

        func mapView(_ m: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let poly = overlay as? TrafficPolyline {
                let r = MKPolylineRenderer(polyline: poly)
                r.lineCap = .round; r.lineJoin = .round
                if poly.isAlternate {
                    r.lineWidth       = 4
                    r.strokeColor     = UIColor.systemGray.withAlphaComponent(0.35)
                    r.lineDashPattern = [8, 6]
                } else {
                    r.lineWidth = 7
                    switch poly.trafficLevel {
                    case .clear:    r.strokeColor = UIColor(red: 0,    green: 0.898, blue: 0.455, alpha: 1)
                    case .moderate: r.strokeColor = UIColor(red: 1,    green: 0.75,  blue: 0,     alpha: 1)
                    case .heavy:    r.strokeColor = UIColor(red: 0.98, green: 0.27,  blue: 0.27,  alpha: 1)
                    case .unknown:  r.strokeColor = UIColor(red: 0,    green: 0.898, blue: 0.455, alpha: 0.6)
                    }
                }
                return r
            }
            let r = MKPolylineRenderer(overlay: overlay)
            r.strokeColor = UIColor.systemGreen.withAlphaComponent(0.7)
            r.lineWidth   = 5
            return r
        }

        func mapView(_ m: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let v = m.dequeueReusableAnnotationView(withIdentifier: "pin")
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
            if let mv = v as? MKMarkerAnnotationView {
                mv.annotation     = annotation
                mv.canShowCallout = true
                switch annotation.title ?? "" {
                case "Pickup":
                    mv.glyphImage      = UIImage(systemName: "figure.wave")
                    mv.markerTintColor = UIColor(red: 0, green: 0.898, blue: 0.455, alpha: 1)
                case "Drop-off":
                    mv.glyphImage      = UIImage(systemName: "flag.checkered")
                    mv.markerTintColor = UIColor(red: 1, green: 0.6, blue: 0, alpha: 1)
                default:
                    mv.glyphText       = "🚗"
                    mv.markerTintColor = .systemBlue
                }
            }
            return v
        }
    }
}

// MARK: - Shared UI
struct ESheetHandle: View {
    var body: some View {
        Capsule().fill(Color.eBorder).frame(width: 40, height: 4).frame(maxWidth: .infinity)
    }
}

struct ECarPin: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.eGreen.opacity(0.12)).frame(width: 34, height: 34)
            Circle().stroke(Color.eGreen.opacity(0.4), lineWidth: 1.5).frame(width: 34, height: 34)
            Text("🚗").font(.system(size: 14))
        }
    }
}

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


func geocode(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
    CLGeocoder().geocodeAddressString(address + ", South Africa") { marks, _ in
        DispatchQueue.main.async {
            completion(marks?.first?.location?.coordinate)
        }
    }
}
