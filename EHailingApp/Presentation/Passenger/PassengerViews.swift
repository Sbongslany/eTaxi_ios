import SwiftUI
import MapKit

// MARK: - Root
struct PassengerRoot: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm: PassengerViewModel
    init(user: UserEntity) { _vm = StateObject(wrappedValue: PassengerViewModel(user: user)) }
    var body: some View {
        Group {
            switch vm.screen {
            case .serviceChoice:  PServiceChoiceView(vm: vm)
            case .home:           PHomeView(vm: vm)
            case .booking:        PBookingView(vm: vm)
            case .findingDriver:  PFindingDriverView(vm: vm)
            case .inRide:         PInRideView(vm: vm)
            case .tripComplete:   PTripCompleteView(vm: vm)
            case .customHire:     PCustomHireView(vm: vm)
            case .hireConfirmed:  PHireConfirmedView(vm: vm)
            case .history:        PHistoryView(vm: vm)
            case .wallet:         PWalletView(vm: vm)
            case .profile:        PProfileView(vm: vm)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.screen)
    }
}

// MARK: - Service Choice
struct PServiceChoiceView: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var appeared = false
    var body: some View {
        ZStack {
            Color.eBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(Color.eGreen).frame(width: 72, height: 72)
                        .shadow(color: Color.eGreen.opacity(0.4), radius: 20, y: 6)
                    Text("eT").font(.system(size: 26, weight: .black, design: .rounded)).foregroundColor(.black)
                }
                .scaleEffect(appeared ? 1 : 0.7).opacity(appeared ? 1 : 0).padding(.bottom, 24)
                Text("How do you want\nto get around?")
                    .font(EFont.display(30, weight: .heavy)).foregroundColor(.eText)
                    .multilineTextAlignment(.center).opacity(appeared ? 1 : 0).padding(.bottom, 8)
                Text("Choose your default service. You can always switch later.")
                    .font(EFont.body(15)).foregroundColor(.eTextSoft).multilineTextAlignment(.center)
                    .padding(.horizontal, 32).opacity(appeared ? 1 : 0).padding(.bottom, 40)
                PServiceCard(emoji: "⚡️", emojiBg: Color.eGreen.opacity(0.18), title: "Standard Ride",
                    badge: "POPULAR", badgeColor: .eGreen, desc: "On-demand metered trips",
                    bullets: ["Pay per km + time","Driver arrives in minutes","Economy · Comfort · XL · Ladies"],
                    borderColor: Color.eGreen.opacity(0.3)) { vm.selectPreference("standard") }
                    .padding(.bottom, 16)
                PServiceCard(emoji: "📅", emojiBg: Color(hex: "#3D2B8F").opacity(0.4), title: "Custom Hire",
                    badge: "FLAT RATE", badgeColor: Color(hex: "#7B6FD8"), desc: "Flat-rate hourly & daily packages",
                    bullets: ["Fixed price — no surprises","Hourly · Half day · Full day","Perfect for events & long trips"],
                    borderColor: Color(hex: "#3D2B8F").opacity(0.5)) { vm.selectPreference("custom") }
                    .padding(.bottom, 32)
                Button { vm.selectPreference("standard") } label: {
                    Text("Skip — use Standard for now").font(EFont.body(14)).foregroundColor(.eTextMuted)
                }
                Spacer()
            }.padding(.horizontal, 20)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { appeared = true } }
    }
}

private struct PServiceCard: View {
    let emoji: String; let emojiBg: Color; let title: String
    let badge: String; let badgeColor: Color; let desc: String
    let bullets: [String]; let borderColor: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                ZStack { RoundedRectangle(cornerRadius: 14).fill(emojiBg).frame(width: 52, height: 52); Text(emoji).font(.system(size: 26)) }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title).font(EFont.body(17, weight: .bold)).foregroundColor(.eText)
                        Text(badge).font(EFont.body(10, weight: .bold)).foregroundColor(badgeColor)
                            .padding(.horizontal, 8).padding(.vertical, 3).background(badgeColor.opacity(0.15)).clipShape(Capsule())
                    }
                    Text(desc).font(EFont.body(13)).foregroundColor(.eTextSoft)
                    ForEach(bullets, id: \.self) { b in HStack(spacing: 8) { Circle().fill(badgeColor).frame(width: 5, height: 5); Text(b).font(EFont.body(12)).foregroundColor(.eTextSoft) } }
                }
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold)).foregroundColor(.eText)
                    .frame(width: 32, height: 32).background(badgeColor).clipShape(Circle())
            }
            .padding(18).background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(borderColor, lineWidth: 1.5))
        }
    }
}

// MARK: - Home
struct PHomeView: View {
    @ObservedObject var vm: PassengerViewModel
    @StateObject private var locMgr = LocationManager.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            EHomeMap(nearbyPins: vm.nearbyPins)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                VStack(spacing: 0) {
                    Color.clear.frame(height: 10)
                    HStack {
                        HStack(spacing: 0) {
                            Text("e").font(EFont.display(20, weight: .heavy)).foregroundColor(.eText)
                            Text("Taxi").font(EFont.display(20, weight: .heavy)).foregroundColor(.eGreen)
                        }
                        Spacer()
                        Button { vm.screen = .profile } label: {
                            ZStack {
                                Circle().fill(Color.eGreen).frame(width: 38, height: 38)
                                Text(vm.user.initials).font(EFont.body(14, weight: .bold)).foregroundColor(.black)
                            }
                        }
                    }.padding(.horizontal, 20).padding(.vertical, 12)
                    HStack(spacing: 8) {
                        Circle().fill(Color.eGreen).frame(width: 8, height: 8)
                        Text(locMgr.address).font(EFont.body(13)).foregroundColor(.eTextSoft).lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.eCard.opacity(0.92)).clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.eBorder, lineWidth: 1))
                    .padding(.horizontal, 20).padding(.bottom, 10)
                }
                .background(LinearGradient(colors: [Color.eBackground.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom))
                Spacer()
                // Hire button
                HStack {
                    Spacer()
                    Button { vm.syncPickup(); vm.screen = .customHire } label: {
                        HStack(spacing: 7) { Text("📅").font(.system(size: 17)); Text("Hire").font(EFont.body(13, weight: .bold)).foregroundColor(.white) }
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .background(Color(hex: "#6366F1")).clipShape(Capsule())
                            .shadow(color: Color(hex: "#6366F1").opacity(0.55), radius: 10, y: 4)
                    }.padding(.trailing, 16)
                }.padding(.bottom, 310)
            }

            // Bottom sheet
            VStack(alignment: .leading, spacing: 0) {
                ESheetHandle().padding(.top, 12).padding(.bottom, 18)
                let h = Calendar.current.component(.hour, from: Date())
                Text("Good \(h < 12 ? "morning" : h < 17 ? "afternoon" : "evening"), \(vm.user.firstName) 👋")
                    .font(EFont.body(13)).foregroundColor(.eTextSoft).padding(.bottom, 4)
                Text("Where to?").font(EFont.display(22, weight: .bold)).foregroundColor(.eText).padding(.bottom, 14)

                Button { vm.syncPickup(); vm.dropoffAddress = ""; vm.dropoffCoord = nil; vm.estimates = [:]; vm.screen = .booking } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .semibold)).foregroundColor(.eGreen)
                        Text("Search destination…").font(EFont.body(15)).foregroundColor(.eTextMuted)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 15).background(Color.eSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.eBorder, lineWidth: 1.5))
                }.padding(.bottom, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PopularPlace.all.prefix(4)) { p in
                            Button { vm.syncPickup(); vm.setPopular(p); vm.screen = .booking } label: {
                                HStack(spacing: 6) { Text(p.emoji).font(.system(size: 15)); Text(p.name).font(EFont.body(13, weight: .semibold)).foregroundColor(.eText) }
                                    .padding(.horizontal, 14).padding(.vertical, 8).background(Color.eSurface).clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.eBorder, lineWidth: 1))
                            }
                        }
                    }
                }.padding(.bottom, 18)

                if !vm.tripHistory.isEmpty {
                    Text("RECENT PLACES").font(EFont.body(11, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.8).padding(.bottom, 10)
                    ForEach(Array(vm.tripHistory.prefix(2).enumerated()), id: \.element.id) { idx, trip in
                        HStack(spacing: 12) {
                            ZStack { RoundedRectangle(cornerRadius: 8).fill(Color.eSurface).frame(width: 38, height: 38); Text("📍").font(.system(size: 16)) }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.dropoffAddress).font(EFont.body(14, weight: .semibold)).foregroundColor(.eText).lineLimit(1)
                                Text(trip.pickupAddress).font(EFont.body(12)).foregroundColor(.eTextMuted).lineLimit(1)
                            }
                            Spacer()
                        }.padding(.vertical, 11)
                        .onTapGesture {
                            vm.syncPickup(); vm.dropoffAddress = trip.dropoffAddress
                            geocode(trip.dropoffAddress) { c in if let c { vm.dropoffCoord = c; vm.screen = .booking; Task { await vm.fetchEstimates() } } }
                        }
                        if idx == 0 { Divider().background(Color.eBorder) }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 100)
            .background(Color.eCard).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.eBorder, lineWidth: 1) }
            .safeAreaInset(edge: .bottom) { PTabBar(vm: vm) }
        }
        .ignoresSafeArea()
        .onAppear { locMgr.start() }
        .onChange(of: locMgr.coordinate) { coord in
            guard let coord else { return }
            vm.pickupCoord   = coord
            vm.pickupAddress = locMgr.address
        }
        .onChange(of: locMgr.address) { vm.pickupAddress = $0 }
        .task { await vm.loadServices() }
    }
}

private struct PTabBar: View {
    @ObservedObject var vm: PassengerViewModel
    var body: some View {
        HStack {
            ptab(0, icon: "map.fill",       label: "Ride",    target: .home)
            ptab(1, icon: "clock.fill",      label: "History", target: .history)
            ptab(2, icon: "creditcard.fill", label: "Wallet",  target: .wallet)
            ptab(3, icon: "person.fill",     label: "Profile", target: .profile)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Color.eCard).overlay(alignment: .top) { Rectangle().fill(Color.eBorder).frame(height: 0.5) }
    }
    @ViewBuilder private func ptab(_ i: Int, icon: String, label: String, target: PScreen) -> some View {
        Button {
            vm.selectedTab = i; vm.screen = target
            if target == .history { Task { await vm.loadHistory() } }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: vm.selectedTab == i ? icon : icon.replacingOccurrences(of: ".fill", with: ""))
                    .font(.system(size: 20)).foregroundColor(vm.selectedTab == i ? .eGreen : .eTextMuted)
                Text(label).font(EFont.body(10, weight: vm.selectedTab == i ? .bold : .regular))
                    .foregroundColor(vm.selectedTab == i ? .eGreen : .eTextMuted)
            }.frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Booking (search + ride options)
struct PBookingView: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var showSearch = true
    var body: some View {
        ZStack(alignment: .bottom) {
            PBookingMap(pickup: vm.pickupCoord, dropoff: vm.dropoffCoord).ignoresSafeArea()
            VStack { HStack { Button { vm.screen = .home } label: { ZStack { RoundedRectangle(cornerRadius: 10).fill(Color.eCard.opacity(0.92)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.eBorder, lineWidth: 1)); Image(systemName: "arrow.left").font(.system(size: 15, weight: .semibold)).foregroundColor(.eText) }.frame(width: 38, height: 38) }; Spacer() }.padding(.horizontal, 16).padding(.top, 54); Spacer() }
            if showSearch { PSearchSheet(vm: vm, showSearch: $showSearch).transition(.move(edge: .bottom)) }
            else          { PRideSheet(vm: vm, onEdit: { withAnimation { showSearch = true } }).transition(.move(edge: .bottom)) }
        }
        .ignoresSafeArea()
        .onAppear { showSearch = vm.dropoffAddress.isEmpty }
        .onChange(of: vm.dropoffAddress) { if !$0.isEmpty { withAnimation { showSearch = false } } }
    }
}

struct PBookingMap: UIViewRepresentable {
    var pickup: CLLocationCoordinate2D?; var dropoff: CLLocationCoordinate2D?
    func makeUIView(context: Context) -> MKMapView {
        let m = MKMapView(); m.delegate = context.coordinator; m.showsUserLocation = true
        m.userTrackingMode = .follow; m.showsCompass = false; m.showsTraffic = true; return m
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let co = context.coordinator
        guard pickup != co.lp || dropoff != co.ld else { return }
        co.lp = pickup; co.ld = dropoff
        map.removeOverlays(map.overlays); map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
        guard let p = pickup, let d = dropoff else { return }
        let pa = MKPointAnnotation(); pa.coordinate = p; pa.title = "Pickup"
        let da = MKPointAnnotation(); da.coordinate = d; da.title = "Drop-off"
        map.addAnnotations([pa, da])
        let req = MKDirections.Request(); req.transportType = .automobile
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: p))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: d))
        MKDirections(request: req).calculate { resp, _ in
            guard let route = resp?.routes.first else { return }
            DispatchQueue.main.async {
                map.addOverlay(route.polyline, level: .aboveRoads)
                map.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 420, right: 40), animated: true)
            }
        }
    }
    func makeCoordinator() -> Coord { Coord() }
    final class Coord: NSObject, MKMapViewDelegate {
        var lp: CLLocationCoordinate2D?; var ld: CLLocationCoordinate2D?
        func mapView(_ m: MKMapView, rendererFor o: MKOverlay) -> MKOverlayRenderer {
            let r = MKPolylineRenderer(overlay: o); r.strokeColor = UIColor(red:0,green:0.898,blue:0.455,alpha:1); r.lineWidth = 6; r.lineCap = .round; return r
        }
        func mapView(_ m: MKMapView, viewFor ann: MKAnnotation) -> MKAnnotationView? {
            guard !(ann is MKUserLocation) else { return nil }
            let v = m.dequeueReusableAnnotationView(withIdentifier: "bpin") ?? MKMarkerAnnotationView(annotation: ann, reuseIdentifier: "bpin")
            if let mv = v as? MKMarkerAnnotationView {
                mv.annotation = ann; mv.canShowCallout = true
                if ann.title == "Pickup" { mv.glyphImage = UIImage(systemName: "figure.wave"); mv.markerTintColor = UIColor(red:0,green:0.898,blue:0.455,alpha:1) }
                else { mv.glyphImage = UIImage(systemName: "flag.checkered"); mv.markerTintColor = UIColor(red:1,green:0.6,blue:0,alpha:1) }
            }
            return v
        }
    }
}

struct PSearchSheet: View {
    @ObservedObject var vm: PassengerViewModel
    @Binding var showSearch: Bool
    @StateObject private var locMgr = LocationManager.shared

    @State private var activeField:  String = "dropoff"
    @State private var pickupText    = ""
    @State private var dropoffText   = ""
    @State private var results:      [MKMapItem] = []
    @State private var search:       MKLocalSearch?
    @FocusState private var pickupFocused:  Bool
    @FocusState private var dropoffFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ESheetHandle().padding(.top, 12).padding(.bottom, 14)

            Text("Plan your trip")
                .font(EFont.display(20, weight: .heavy))
                .foregroundColor(.eText)
                .padding(.horizontal, 20).padding(.bottom, 16)

            // Route card
            VStack(spacing: 0) {

                // ── Pickup row ──────────────────────────────────────
                HStack(spacing: 12) {
                    Circle().fill(Color.eGreen).frame(width: 10, height: 10)

                    TextField("Pickup location", text: $pickupText)
                        .font(EFont.body(14))
                        .foregroundColor(.eText)
                        .tint(.eGreen)
                        .focused($pickupFocused)
                        .onChange(of: pickupFocused) { focused in
                            if focused {
                                activeField    = "pickup"
                                dropoffFocused = false
                                if pickupText.isEmpty { pickupText = vm.pickupAddress }
                            }
                        }
                        .onChange(of: pickupText) { text in
                            if activeField == "pickup" { runSearch(text) }
                        }

                    if activeField == "pickup" {
                        if !pickupText.isEmpty {
                            Button { pickupText = ""; results = [] } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.eTextMuted)
                            }
                        }
                        Button {
                            if let c = locMgr.coordinate {
                                vm.pickupCoord   = c
                                vm.pickupAddress = locMgr.address
                                pickupText       = locMgr.address
                                results          = []
                                dropoffFocused   = true
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.eGreen)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(activeField == "pickup" ? Color.eGreen.opacity(0.06) : Color.clear)

                Divider().background(Color.eBorder).padding(.leading, 38)

                // ── Swap button ─────────────────────────────────────
                HStack {
                    Rectangle().fill(Color.eBorder).frame(width: 1, height: 14).padding(.leading, 16)
                    Spacer()
                    Button {
                        let tmpA = vm.pickupAddress;  let tmpC = vm.pickupCoord
                        vm.pickupAddress  = vm.dropoffAddress; vm.pickupCoord  = vm.dropoffCoord
                        vm.dropoffAddress = tmpA;              vm.dropoffCoord = tmpC
                        pickupText  = vm.pickupAddress
                        dropoffText = vm.dropoffAddress
                        results = []
                    } label: {
                        ZStack {
                            Circle().fill(Color.eSurface)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(Color.eBorder, lineWidth: 1))
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.eTextMuted)
                        }
                    }.padding(.trailing, 16)
                }

                Divider().background(Color.eBorder).padding(.leading, 38)

                // ── Dropoff row ──────────────────────────────────────
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.eAccent).frame(width: 10, height: 10)

                    TextField("Search destination…", text: $dropoffText)
                        .font(EFont.body(14))
                        .foregroundColor(.eText)
                        .tint(.eGreen)
                        .focused($dropoffFocused)
                        .onChange(of: dropoffFocused) { if $0 { activeField = "dropoff"; pickupFocused = false } }
                        .onChange(of: dropoffText) { text in
                            if activeField == "dropoff" { runSearch(text) }
                        }

                    if !dropoffText.isEmpty {
                        Button { dropoffText = ""; results = [] } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.eTextMuted)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(activeField == "dropoff" ? Color.eGreen.opacity(0.06) : Color.clear)
            }
            .background(Color.eSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.eBorder, lineWidth: 1))
            .padding(.horizontal, 20).padding(.bottom, 20)

            // ── Results / Popular ──────────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if !results.isEmpty {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                            Button { selectResult(item) } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10).fill(Color.eSurface).frame(width: 44, height: 44)
                                        Image(systemName: "mappin").font(.system(size: 18)).foregroundColor(.eTextMuted)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "").font(EFont.body(15, weight: .semibold)).foregroundColor(.eText)
                                        Text(item.placemark.locality ?? "").font(EFont.body(12)).foregroundColor(.eTextMuted).lineLimit(1)
                                    }
                                    Spacer()
                                }.padding(.horizontal, 20).padding(.vertical, 12)
                            }
                            Divider().background(Color.eBorder).padding(.leading, 76)
                        }
                    } else {
                        Text("POPULAR DESTINATIONS")
                            .font(EFont.body(11, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.8)
                            .padding(.horizontal, 20).padding(.bottom, 12)
                        ForEach(PopularPlace.all) { p in
                            Button { selectPopular(p) } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10).fill(Color.eSurface).frame(width: 44, height: 44)
                                        Text(p.emoji).font(.system(size: 20))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.name).font(EFont.body(15, weight: .semibold)).foregroundColor(.eText)
                                        Text(p.address).font(EFont.body(12)).foregroundColor(.eTextMuted).lineLimit(1)
                                    }
                                    Spacer()
                                }.padding(.horizontal, 20).padding(.vertical, 12)
                            }
                            Divider().background(Color.eBorder).padding(.leading, 76)
                        }
                    }
                }
            }
            .frame(maxHeight: 340)
        }
        .background(Color.eCard)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.eBorder, lineWidth: 1)
        }
        .onAppear {
            // Start with dropoff focused, show pickup address in its field
            pickupText  = vm.pickupAddress
            dropoffText = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dropoffFocused = true }
        }
    }

    private func selectResult(_ item: MKMapItem) {
        let addr  = [item.name, item.placemark.locality].compactMap { $0 }.joined(separator: ", ")
        let coord = item.placemark.coordinate
        if activeField == "pickup" {
            vm.pickupAddress = addr
            vm.pickupCoord   = coord
            pickupText       = addr
            results          = []
            dropoffFocused   = true
        } else {
            vm.setDestination(addr, coord: coord)
            withAnimation { showSearch = false }
        }
    }

    private func selectPopular(_ p: PopularPlace) {
        if activeField == "pickup" {
            vm.pickupAddress = p.address
            vm.pickupCoord   = .init(latitude: p.lat, longitude: p.lon)
            pickupText       = p.address
            results          = []
            dropoffFocused   = true
        } else {
            vm.setPopular(p)
            withAnimation { showSearch = false }
        }
    }

    private func runSearch(_ text: String) {
        guard !text.isEmpty else { results = []; return }
        search?.cancel()
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = text
        req.resultTypes          = [.address, .pointOfInterest]
        req.region = MKCoordinateRegion(
            center: locMgr.coordinate ?? .init(latitude: -26.1076, longitude: 28.0567),
            span:   .init(latitudeDelta: 0.5, longitudeDelta: 0.5))
        search = MKLocalSearch(request: req)
        search?.start { resp, _ in
            DispatchQueue.main.async {
                self.results = resp?.mapItems.prefix(6).map { $0 } ?? []
            }
        }
    }
}


struct PRideSheet: View {
    @ObservedObject var vm: PassengerViewModel; var onEdit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ESheetHandle().padding(.top, 12).padding(.bottom, 16)
            VStack(spacing: 0) {
                HStack(spacing: 12) { Circle().fill(Color.eGreen).frame(width: 10, height: 10); Text(vm.pickupAddress).font(EFont.body(14)).foregroundColor(.eText).lineLimit(1); Spacer() }.padding(.vertical, 10)
                Rectangle().fill(Color.eBorder).frame(width: 1, height: 14).padding(.leading, 6)
                Button(action: onEdit) { HStack(spacing: 12) { Circle().fill(Color.eAccent).frame(width: 10, height: 10); Text(vm.dropoffAddress.isEmpty ? "Tap to set destination…" : vm.dropoffAddress).font(EFont.body(14)).foregroundColor(.eText).lineLimit(1); Spacer() }.padding(.vertical, 10) }
            }.padding(14).background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.eBorder, lineWidth: 1)).padding(.horizontal, 20).padding(.bottom, 16)
            Text("CHOOSE RIDE").font(EFont.body(11, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.8).padding(.horizontal, 20).padding(.bottom, 10)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(vm.standardServices) { svc in
                        let est = vm.estimates[svc.key]; let fare = est?.estimated ?? est?.min; let dur = est?.durationMin; let sel = vm.selectedService?.id == svc.id
                        Button { vm.selectedService = svc } label: {
                            HStack(spacing: 14) {
                                Text(svc.emoji).font(.system(size: 32)).frame(width: 48)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(svc.name).font(EFont.body(16, weight: .bold)).foregroundColor(.eText)
                                    Text("\(svc.maxPassengers) seats · \(svc.vehicleType.capitalized)").font(EFont.body(12)).foregroundColor(.eTextMuted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    HStack(spacing: 4) {
                                        if sel { Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundColor(.eGreen) }
                                        Text(fare.map { "R\(Int($0))" } ?? svc.displayPrice).font(EFont.display(18, weight: .heavy)).foregroundColor(.eText)
                                    }
                                    if let d = dur { Text("~\(Int(d)) min").font(EFont.body(11)).foregroundColor(.eTextMuted) }
                                }
                            }.padding(14)
                            .background(sel ? Color.eGreen.opacity(0.08) : Color.eSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(sel ? Color.eGreen : Color.eBorder, lineWidth: sel ? 2 : 1))
                        }
                    }
                }.padding(.horizontal, 20).padding(.bottom, 12)
            }.frame(maxHeight: 260)
            if let err = vm.errorMessage { EErrorBanner(message: err).padding(.horizontal, 20).padding(.bottom, 8) }
            EPrimaryButton(title: vm.confirmTitle, isLoading: vm.isLoading) { vm.confirmRide() }.padding(.horizontal, 20).padding(.bottom, 36)
        }
        .background(Color.eCard).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.eBorder, lineWidth: 1) }
    }
}

// MARK: - Finding Driver
struct PFindingDriverView: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var spin: Double = 0
    var status: String { vm.currentTrip?.status ?? "searching" }
    var isSearching: Bool { status == "searching" }
    var body: some View {
        ZStack(alignment: .bottom) {
            ETaxiMap(origin: vm.driverCoord ?? vm.pickupCoord, target: vm.pickupCoord,
                     isPickup: true, fitRoute: true,
                     eta: $vm.mapEta, distance: $vm.mapDist, traffic: $vm.mapTraffic).ignoresSafeArea()
            VStack(spacing: 0) {
                ESheetHandle().padding(.top, 12).padding(.bottom, 16)
                VStack(spacing: 14) {
                    if vm.searchTimedOut {
                        PNoDriverSheet(vm: vm)
                    } else {
                        HStack(spacing: 10) {
                            if isSearching {
                                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 15, weight: .bold)).foregroundColor(.eGreen)
                                    .rotationEffect(.degrees(spin)).animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: spin)
                            } else { Image(systemName: "checkmark.circle.fill").font(.system(size: 15)).foregroundColor(.eGreen) }
                            Text(vm.currentTrip?.statusLabel ?? "Finding driver…").font(EFont.body(15, weight: .bold)).foregroundColor(.eText); Spacer()
                            if isSearching { Text("\(vm.searchSeconds)s").font(EFont.mono(14)).foregroundColor(.eTextSoft) }
                        }.padding(.horizontal, 16).padding(.vertical, 14).background(Color.eGreen.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 14))

                        if isSearching {
                            GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(Color.eSurface2).frame(height: 3); Capsule().fill(Color.eGreen).frame(width: CGFloat(60 - vm.searchSeconds) / 60.0 * geo.size.width, height: 3).animation(.linear(duration: 1), value: vm.searchSeconds) } }.frame(height: 3)
                        }

                        if let t = vm.currentTrip, !isSearching, let name = t.driverName {
                            HStack(spacing: 14) {
                                ZStack { Circle().fill(Color.eGreen.opacity(0.15)).frame(width: 48, height: 48); Text(String(name.prefix(1))).font(EFont.display(20, weight: .bold)).foregroundColor(.eGreen) }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(name).font(EFont.body(15, weight: .bold)).foregroundColor(.eText)
                                    if let v = t.vehicleInfo { Text(v).font(EFont.body(12)).foregroundColor(.eTextSoft) }
                                    if let c = t.driverCode  { Text("Code: \(c)").font(EFont.body(11, weight: .bold)).foregroundColor(.eGreen) }
                                }
                                Spacer()
                                HStack(spacing: 2) { Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(.eAccent); Text("4.9").font(EFont.body(13, weight: .bold)).foregroundColor(.eText) }
                            }.padding(14).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ARRIVING IN").font(EFont.body(11, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.8)
                                Text(vm.mapEta).font(EFont.display(42, weight: .heavy)).foregroundColor(.eGreen)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("FARE").font(EFont.body(11, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.8)
                                Text(vm.currentTrip?.fareStr ?? "R0").font(EFont.display(26, weight: .heavy)).foregroundColor(.eText)
                            }
                        }.padding(16).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 16))

                        HStack(spacing: 12) {
                            PActionBtn(icon: "phone.fill",          label: "Call")
                            PActionBtn(icon: "message.fill",        label: "Chat")
                            PActionBtn(icon: "square.and.arrow.up", label: "Share", color: .eGreen)
                        }
                        Button { vm.cancelRide() } label: {
                            Text("Cancel Ride").font(EFont.body(15, weight: .semibold)).foregroundColor(.eRed)
                                .frame(maxWidth: .infinity).frame(height: 50).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }.padding(.horizontal, 20).padding(.bottom, 36)
            }
            .background(Color.eCard).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .ignoresSafeArea().onAppear { spin = 360 }
    }
}

private struct PNoDriverSheet: View {
    @ObservedObject var vm: PassengerViewModel
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill").font(.system(size: 40)).foregroundColor(.eTextMuted.opacity(0.4))
            Text("No Drivers Available").font(EFont.display(20, weight: .heavy)).foregroundColor(.eText)
            Text("We couldn't find a driver nearby.\nTry again in a few minutes.")
                .font(EFont.body(14)).foregroundColor(.eTextSoft).multilineTextAlignment(.center)
            EPrimaryButton(title: "Try Again") { vm.retryRide() }
            Button { vm.dismissNoDriver() } label: {
                Text("Back to Home").font(EFont.body(15, weight: .semibold)).foregroundColor(.eTextMuted)
                    .frame(maxWidth: .infinity).frame(height: 48).background(Color.eSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.eBorder, lineWidth: 1.5))
            }
        }
    }
}

private struct PActionBtn: View {
    let icon: String; let label: String; var color: Color = .eText
    var body: some View {
        Button {} label: {
            VStack(spacing: 6) { Image(systemName: icon).font(.system(size: 18)).foregroundColor(color); Text(label).font(EFont.body(12, weight: .semibold)).foregroundColor(color) }
                .frame(maxWidth: .infinity).frame(height: 56).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - In Ride
struct PInRideView: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var showCancel = false
    var body: some View {
        ZStack(alignment: .bottom) {
            ETaxiMap(origin: vm.driverCoord ?? vm.pickupCoord, target: vm.dropoffCoord,
                     isPickup: false, fitRoute: false,
                     eta: $vm.mapEta, distance: $vm.mapDist, traffic: $vm.mapTraffic).ignoresSafeArea()
            VStack {
                HStack {
                    HStack(spacing: 8) { Circle().fill(Color.eGreen).frame(width: 8, height: 8); Text("In Ride").font(EFont.body(13, weight: .bold)).foregroundColor(.eText) }
                        .padding(.horizontal, 14).padding(.vertical, 8).background(Color.eCard.opacity(0.95)).clipShape(Capsule())
                    Spacer()
                    VStack(spacing: 2) { Text(vm.mapEta).font(EFont.display(18, weight: .heavy)).foregroundColor(.eGreen); Text("to dropoff").font(EFont.body(10)).foregroundColor(.eTextSoft) }
                        .padding(.horizontal, 14).padding(.vertical, 8).background(Color.eCard.opacity(0.95)).clipShape(RoundedRectangle(cornerRadius: 12))
                }.padding(.horizontal, 16).padding(.top, 54)
                if vm.mapTraffic == .heavy {
                    HStack(spacing: 8) { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.eAccent); Text("Heavy traffic ahead").font(EFont.body(13, weight: .semibold)).foregroundColor(.eText) }
                        .padding(.horizontal, 14).padding(.vertical, 8).background(Color.eAccent.opacity(0.15)).clipShape(Capsule()).padding(.top, 8)
                }
                Spacer()
            }
            VStack(spacing: 14) {
                ESheetHandle().padding(.top, 12)
                HStack(spacing: 14) {
                    VStack(spacing: 6) { Circle().fill(Color.eGreen).frame(width: 10, height: 10); Rectangle().fill(Color.eBorder).frame(width: 1, height: 20); Circle().fill(Color.eAccent).frame(width: 10, height: 10) }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(vm.currentTrip?.pickupAddress ?? vm.pickupAddress).font(EFont.body(14, weight: .semibold)).foregroundColor(.eText).lineLimit(1)
                        Text(vm.currentTrip?.dropoffAddress ?? vm.dropoffAddress).font(EFont.body(14, weight: .semibold)).foregroundColor(.eText).lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) { Text(vm.mapDist).font(EFont.body(13, weight: .bold)).foregroundColor(.eTextSoft); Text(vm.mapEta).font(EFont.body(13, weight: .bold)).foregroundColor(.eGreen) }
                }.padding(16).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 16))
                if let t = vm.currentTrip, let name = t.driverName {
                    HStack(spacing: 14) {
                        ZStack { Circle().fill(Color.eGreen.opacity(0.15)).frame(width: 44, height: 44); Text(String(name.prefix(1))).font(EFont.display(18, weight: .bold)).foregroundColor(.eGreen) }
                        VStack(alignment: .leading, spacing: 2) { Text(name).font(EFont.body(14, weight: .bold)).foregroundColor(.eText); if let v = t.vehicleInfo { Text(v).font(EFont.body(12)).foregroundColor(.eTextSoft) } }
                        Spacer()
                        HStack(spacing: 10) {
                            Button {} label: { Image(systemName: "phone.fill").font(.system(size: 16)).foregroundColor(.eText).frame(width: 38, height: 38).background(Color.eSurface).clipShape(Circle()) }
                            Button {} label: { Image(systemName: "message.fill").font(.system(size: 16)).foregroundColor(.eText).frame(width: 38, height: 38).background(Color.eSurface).clipShape(Circle()) }
                        }
                    }.padding(14).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 14))
                }
                if vm.currentTrip?.canCancel == true {
                    Button { showCancel = true } label: {
                        Text("Cancel Ride").font(EFont.body(15, weight: .semibold)).foregroundColor(.eRed)
                            .frame(maxWidth: .infinity).frame(height: 48).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }.padding(.horizontal, 20).padding(.bottom, 36)
            .background(Color.eCard).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .ignoresSafeArea()
        .alert("Cancel Ride?", isPresented: $showCancel) { Button("Cancel Ride", role: .destructive) { vm.cancelRide() }; Button("Keep Ride", role: .cancel) {} } message: { Text("A cancellation fee may apply.") }
    }
}

// MARK: - Trip Complete
struct PTripCompleteView: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var appeared = false
    let tags: [String] = ["Great driver","Clean car","On time","Safe driving","Friendly","Smooth ride"]
    var body: some View {
        ZStack { Color.eBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer(minLength: 40)
                    ZStack {
                        Circle().fill(Color.eGreen.opacity(0.12)).frame(width: 120, height: 120).scaleEffect(appeared ? 1 : 0.5)
                        Image(systemName: "checkmark").font(.system(size: 44, weight: .bold)).foregroundColor(.eGreen).scaleEffect(appeared ? 1 : 0)
                    }.animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)
                    Text("Trip Complete").font(EFont.display(24, weight: .heavy)).foregroundColor(.eText)
                    Text(vm.currentTrip?.fareStr ?? "R0").font(.system(size: 56, weight: .black, design: .rounded)).foregroundColor(.eText)
                        .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)
                    if let t = vm.currentTrip {
                        VStack(spacing: 0) {
                            tcRow(icon: "location.fill", color: .eGreen, label: "Pickup", val: t.pickupAddress)
                            Divider().background(Color.eBorder).padding(.leading, 54)
                            tcRow(icon: "flag.checkered", color: .eAccent, label: "Dropoff", val: t.dropoffAddress)
                            if let km = t.estimatedDistanceKm { Divider().background(Color.eBorder).padding(.leading, 54); tcRow(icon: "road.lanes", color: .eTextSoft, label: "Distance", val: String(format: "%.1f km", km)) }
                        }.background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 20)
                    }
                    Text("Rate your driver").font(EFont.body(16, weight: .bold)).foregroundColor(.eText)
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { star in
                            Button { withAnimation { vm.selectedRating = star } } label: {
                                Image(systemName: star <= vm.selectedRating ? "star.fill" : "star").font(.system(size: 36)).foregroundColor(star <= vm.selectedRating ? .eAccent : .eTextMuted).scaleEffect(star == vm.selectedRating ? 1.15 : 1)
                            }
                        }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                        ForEach(tags, id: \.self) { tag in
                            ratingTagChip(tag)
                        }
                    }.padding(.horizontal, 20)
                    EPrimaryButton(title: "Submit Rating") { vm.submitRating() }.padding(.horizontal, 20)
                    Button { vm.goHome() } label: { Text("Skip").font(EFont.body(14)).foregroundColor(.eTextMuted).frame(maxWidth: .infinity).padding(.vertical, 14) }
                    Spacer(minLength: 40)
                }
            }
        }.onAppear { withAnimation { appeared = true } }
    }
    @ViewBuilder private func ratingTagChip(_ tag: String) -> some View {
        let sel = vm.ratingTags.contains(tag)
        Button {
            withAnimation { if sel { vm.ratingTags.remove(tag) } else { vm.ratingTags.insert(tag) } }
        } label: {
            Text(tag)
                .font(EFont.body(13, weight: sel ? .bold : .regular))
                .foregroundColor(sel ? .black : .eText)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(sel ? Color.eGreen : Color.eSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(sel ? Color.clear : Color.eBorder, lineWidth: 1))
        }
    }
    @ViewBuilder private func tcRow(icon: String, color: Color, label: String, val: String) -> some View {
        HStack(spacing: 14) {
            ZStack { RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)).frame(width: 36, height: 36); Image(systemName: icon).font(.system(size: 14)).foregroundColor(color) }
            VStack(alignment: .leading, spacing: 2) { Text(label).font(EFont.body(11)).foregroundColor(.eTextMuted); Text(val).font(EFont.body(14, weight: .semibold)).foregroundColor(.eText).lineLimit(1) }
            Spacer()
        }.padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - Custom Hire
struct PCustomHireView: View {
    @ObservedObject var vm: PassengerViewModel
    @StateObject private var locMgr = LocationManager.shared
    @State private var mapRegion = MKCoordinateRegion(center: .init(latitude: -26.1076, longitude: 28.0567), span: .init(latitudeDelta: 0.02, longitudeDelta: 0.02))
    @State private var showDatePicker = false
    let durations: [(String, String, String)] = [("⏰","Hourly","hourly"),("🌤","Half Day","halfday"),("☀️","Full Day","fullday"),("🏖","Weekend","weekend")]
    var body: some View {
        ZStack {
            Map(coordinateRegion: $mapRegion, showsUserLocation: true).ignoresSafeArea()
            VStack {
                HStack {
                    Button { vm.screen = .home } label: { Image(systemName: "arrow.left").font(.system(size: 16, weight: .semibold)).foregroundColor(.eText).frame(width: 42, height: 42).background(Color.eSurface.opacity(0.95)).clipShape(RoundedRectangle(cornerRadius: 12)) }
                    VStack(alignment: .leading, spacing: 2) { Text("Custom Hire").font(EFont.display(18, weight: .heavy)).foregroundColor(.eText); Text("Flat-rate packages").font(EFont.body(12)).foregroundColor(.eTextSoft) }.padding(.leading, 8)
                    Spacer()
                    Button { vm.screen = .booking } label: { HStack(spacing: 5) { Text("⚡️").font(.system(size: 11)); Text("Standard").font(EFont.body(12, weight: .bold)).foregroundColor(.eGreen) }.padding(.horizontal, 12).padding(.vertical, 7).background(Color.eGreen.opacity(0.12)).clipShape(Capsule()) }
                }.padding(.horizontal, 16).padding(.top, 52); Spacer()
            }
            VStack {
                Spacer()
                VStack(spacing: 0) {
                    ESheetHandle().padding(.top, 12).padding(.bottom, 16)
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            VStack(spacing: 0) {
                                HStack(spacing: 12) { Circle().fill(Color.eGreen).frame(width: 10, height: 10); Text(vm.pickupAddress.isEmpty ? "Pickup location" : vm.pickupAddress).font(EFont.body(15)).foregroundColor(vm.pickupAddress.isEmpty ? .eTextMuted : .eText).lineLimit(1); Spacer() }.padding(.horizontal, 16).padding(.vertical, 14)
                                Divider().background(Color.eBorder).padding(.leading, 38)
                                HStack(spacing: 12) { ZStack { Circle().stroke(Color.eTextSoft, lineWidth: 1.5).frame(width: 10, height: 10); Circle().fill(Color.eTextSoft).frame(width: 5, height: 5) }; Text(vm.dropoffAddress.isEmpty ? "Destination (optional)" : vm.dropoffAddress).font(EFont.body(15)).foregroundColor(vm.dropoffAddress.isEmpty ? .eTextMuted : .eText).lineLimit(1); Spacer() }.padding(.horizontal, 16).padding(.vertical, 14)
                            }.background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 16))
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Start Date & Time", systemImage: "calendar").font(EFont.body(14, weight: .semibold)).foregroundColor(.eTextSoft)
                                HStack(spacing: 12) {
                                    Button { showDatePicker.toggle() } label: { Text(vm.hireDate.formatted(.dateTime.day().month(.abbreviated).year())).font(EFont.body(16, weight: .bold)).foregroundColor(.eText).padding(.horizontal, 16).padding(.vertical, 12).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 12)) }
                                    Button { showDatePicker.toggle() } label: { Text(vm.hireDate.formatted(.dateTime.hour().minute())).font(EFont.body(16, weight: .bold)).foregroundColor(.eText).padding(.horizontal, 16).padding(.vertical, 12).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 12)) }
                                }
                                if showDatePicker { DatePicker("", selection: $vm.hireDate, in: Date()...).datePickerStyle(.graphical).tint(.eGreen) }
                            }.padding(16).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 16))
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Duration", systemImage: "clock").font(EFont.body(14, weight: .semibold)).foregroundColor(.eTextSoft)
                                HStack(spacing: 10) {
                                    ForEach(durations, id: \.1) { emoji, label, key in
                                        let sel = vm.hireDuration == key
                                        Button { withAnimation(.spring(response: 0.3)) { vm.hireDuration = key } } label: {
                                            VStack(spacing: 6) { Text(emoji).font(.system(size: 24)); Text(label).font(EFont.body(12, weight: sel ? .bold : .regular)).foregroundColor(sel ? .black : .eText) }
                                                .frame(maxWidth: .infinity).frame(height: 72)
                                                .background(sel ? Color(hex: "#6366F1") : Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 14))
                                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(sel ? Color.clear : Color.eBorder, lineWidth: 1))
                                        }
                                    }
                                }
                            }.padding(16).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 16))
                            if let err = vm.errorMessage { EErrorBanner(message: err) }
                            Spacer(minLength: 80)
                        }.padding(.horizontal, 20)
                    }
                }.background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous)).frame(maxHeight: UIScreen.main.bounds.height * 0.72)
                Button { vm.confirmHire() } label: {
                    HStack(spacing: 10) { Image(systemName: "calendar.badge.checkmark").foregroundColor(.black); Text(vm.hireEstimatedFare > 0 ? "Confirm Hire · R\(Int(vm.hireEstimatedFare))" : "Confirm Hire").font(EFont.body(16, weight: .bold)).foregroundColor(.black) }
                        .frame(maxWidth: .infinity).frame(height: 56).background(vm.isLoading ? Color.eSurface : Color(hex: "#6366F1")).clipShape(RoundedRectangle(cornerRadius: 16))
                }.disabled(vm.isLoading).padding(.horizontal, 20).padding(.vertical, 12).background(Color.eSurface)
            }
        }.ignoresSafeArea().onAppear { if let c = locMgr.coordinate { mapRegion.center = c } }
    }
}

// MARK: - Hire Confirmed
struct PHireConfirmedView: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var remaining: TimeInterval = 0; @State private var timer: Timer?
    var pickupDate: Date {
        guard let s = vm.currentTrip?.scheduledAt, let d = ISO8601DateFormatter().date(from: s) else { return vm.hireDate }
        return d
    }
    var countdown: String {
        let t = Int(remaining); guard t > 0 else { return "Now!" }
        let d=t/86400; let h=(t%86400)/3600; let m=(t%3600)/60
        if d > 0 { return "\(d)d \(h)h \(m)m" }; if h > 0 { return "\(h)h \(m)m" }; return "\(m)m"
    }
    var body: some View {
        ZStack { Color.eBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 32)
                    HStack(spacing: 10) { Circle().fill(Color(hex: "#6366F1")).frame(width: 10, height: 10); Text("Hire Confirmed").font(EFont.body(16, weight: .bold)).foregroundColor(.eText) }
                        .padding(.horizontal, 20).padding(.vertical, 12).background(Color(hex: "#1E1B3A")).clipShape(Capsule())
                    Text(countdown).font(.system(size: 56, weight: .black, design: .rounded)).foregroundColor(.eText)
                    Text("until pickup").font(EFont.body(16)).foregroundColor(.eTextSoft)
                    VStack(spacing: 0) {
                        hcRow(icon: "calendar", bg: Color(hex: "#2A2460"), label: "Start", val: pickupDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                        Divider().background(Color.eBorder).padding(.leading, 56)
                        hcRow(icon: "clock.fill", bg: Color(hex: "#3A2A00"), label: "Duration", val: "\(vm.hireDurationHours) hr\(vm.hireDurationHours > 1 ? "s" : "")")
                        Divider().background(Color.eBorder).padding(.leading, 56)
                        hcRow(icon: "location.fill", bg: Color.eGreen.opacity(0.2), label: "Pickup", val: vm.pickupAddress)
                        if !vm.dropoffAddress.isEmpty { Divider().background(Color.eBorder).padding(.leading, 56); hcRow(icon: "mappin", bg: Color(hex: "#1A1A3A"), label: "Destination", val: vm.dropoffAddress) }
                        Divider().background(Color.eBorder).padding(.leading, 56)
                        hcRow(icon: "banknote.fill", bg: Color(hex: "#2A2000"), label: "Total Fare", val: "R\(Int(vm.currentTrip?.totalFare ?? vm.hireEstimatedFare))")
                    }.background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 20)
                    EPrimaryButton(title: "Done") { vm.goHome() }.padding(.horizontal, 20)
                    Spacer(minLength: 40)
                }
            }
        }
        .onAppear { remaining = pickupDate.timeIntervalSinceNow; timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in remaining = pickupDate.timeIntervalSinceNow } }
        .onDisappear { timer?.invalidate() }
    }
    @ViewBuilder private func hcRow(icon: String, bg: Color, label: String, val: String) -> some View {
        HStack(spacing: 14) {
            ZStack { RoundedRectangle(cornerRadius: 10).fill(bg).frame(width: 36, height: 36); Image(systemName: icon).font(.system(size: 16)).foregroundColor(.eText) }
            VStack(alignment: .leading, spacing: 2) { Text(label).font(EFont.body(12)).foregroundColor(.eTextSoft); Text(val).font(EFont.body(15, weight: .semibold)).foregroundColor(.eText) }
            Spacer()
        }.padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - History
struct PHistoryView: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var filter: String? = nil
    var filtered: [BETrip] {
        guard let f = filter else { return vm.tripHistory }
        return vm.tripHistory.filter { f == "cancelled" ? $0.status.contains("cancelled") || $0.status == "no_driver_found" : $0.status == f }
    }
    var body: some View {
        ZStack { Color.eBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { vm.screen = .home } label: { Image(systemName: "arrow.left").font(.system(size: 16, weight: .semibold)).foregroundColor(.eText).frame(width: 38, height: 38).background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 10)) }
                    Text("My Trips").font(EFont.display(22, weight: .heavy)).foregroundColor(.eText); Spacer()
                }.padding(.horizontal, 20).padding(.top, 54).padding(.bottom, 16)
                HStack(spacing: 10) { phFilter("All", nil); phFilter("Completed", "completed"); phFilter("Cancelled", "cancelled") }.padding(.horizontal, 20).padding(.bottom, 16)
                if vm.tripHistory.isEmpty {
                    Spacer()
                    VStack(spacing: 16) { Image(systemName: "car.fill").font(.system(size: 48)).foregroundColor(.eTextMuted); Text("No trips yet").font(EFont.display(20, weight: .heavy)).foregroundColor(.eText); Text("Your trips will appear here").font(EFont.body(14)).foregroundColor(.eTextSoft) }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) { LazyVStack(spacing: 12) { ForEach(filtered) { phCard($0) } }.padding(.horizontal, 20).padding(.bottom, 40) }
                }
            }
        }.task { await vm.loadHistory() }
    }
    @ViewBuilder private func phFilter(_ label: String, _ key: String?) -> some View {
        Button { withAnimation { filter = key } } label: {
            Text(label).font(EFont.body(13, weight: filter == key ? .bold : .regular)).foregroundColor(filter == key ? .black : .eText)
                .padding(.horizontal, 16).padding(.vertical, 8).background(filter == key ? Color.eGreen : Color.eSurface).clipShape(Capsule())
        }
    }
    @ViewBuilder private func phCard(_ trip: BETrip) -> some View {
        let color: Color = trip.status == "completed" ? .eGreen : trip.status.contains("cancelled") ? .eRed : .eTextSoft
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) { Text(trip.rideType.capitalized).font(EFont.body(11, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.5); Text(trip.pickupAddress).font(EFont.body(14, weight: .semibold)).foregroundColor(.eText).lineLimit(1) }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) { Text(trip.fareStr).font(EFont.display(18, weight: .heavy)).foregroundColor(.eText); Text(trip.statusLabel).font(EFont.body(11, weight: .bold)).foregroundColor(color) }
            }.padding(.horizontal, 16).padding(.top, 16)
            Divider().background(Color.eBorder).padding(.horizontal, 16).padding(.vertical, 10)
            HStack(spacing: 10) {
                Image(systemName: "mappin").font(.system(size: 12)).foregroundColor(.eTextMuted)
                Text(trip.dropoffAddress).font(EFont.body(13)).foregroundColor(.eTextSoft).lineLimit(1); Spacer()
                if let km = trip.estimatedDistanceKm { Text(String(format: "%.1f km", km)).font(EFont.body(12)).foregroundColor(.eTextMuted) }
            }.padding(.horizontal, 16).padding(.bottom, 16)
        }.background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.eBorder, lineWidth: 1))
    }
}

// MARK: - Wallet
struct PWalletView: View {
    @ObservedObject var vm: PassengerViewModel
    var body: some View {
        ZStack { Color.eBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack { Button { vm.screen = .home } label: { Image(systemName: "arrow.left").font(.system(size: 16, weight: .semibold)).foregroundColor(.eText).frame(width: 38, height: 38).background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 10)) }; Text("Wallet").font(EFont.display(22, weight: .heavy)).foregroundColor(.eText); Spacer() }.padding(.horizontal, 20).padding(.top, 54)
                Spacer(); Image(systemName: "creditcard.fill").font(.system(size: 48)).foregroundColor(.eTextSoft); Text("Wallet coming soon").font(EFont.body(15)).foregroundColor(.eTextSoft); Spacer()
            }
        }
    }
}

// MARK: - Profile
struct PProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var vm: PassengerViewModel
    var body: some View {
        ZStack { Color.eBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack { Button { vm.screen = .home } label: { Image(systemName: "arrow.left").font(.system(size: 16, weight: .semibold)).foregroundColor(.eText).frame(width: 38, height: 38).background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 10)) }; Text("Profile").font(EFont.display(22, weight: .heavy)).foregroundColor(.eText); Spacer() }.padding(.horizontal, 20).padding(.top, 54).padding(.bottom, 28)
                    ZStack { Circle().fill(Color.eGreen).frame(width: 88, height: 88); Text(vm.user.initials).font(EFont.display(32, weight: .heavy)).foregroundColor(.black) }.padding(.bottom, 16)
                    Text(vm.user.fullName).font(EFont.display(22, weight: .heavy)).foregroundColor(.eText)
                    Text(vm.user.phone).font(EFont.body(15)).foregroundColor(.eTextSoft).padding(.bottom, 8)
                    VStack(spacing: 0) {
                        ppRow(icon: "clock", label: "Trip History") { vm.screen = .history; Task { await vm.loadHistory() } }
                        Divider().background(Color.eBorder).padding(.leading, 54)
                        ppRow(icon: "creditcard", label: "Wallet") { vm.screen = .wallet }
                        Divider().background(Color.eBorder).padding(.leading, 54)
                        ppRow(icon: "questionmark.circle", label: "Help & Support") {}
                    }.background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 20).padding(.top, 28)
                    Button { authVM.logout() } label: {
                        HStack { Image(systemName: "rectangle.portrait.and.arrow.right"); Text("Sign Out") }
                            .font(EFont.body(15, weight: .semibold)).foregroundColor(.eRed)
                            .frame(maxWidth: .infinity).frame(height: 52).background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.eBorder, lineWidth: 1))
                    }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 40)
                }
            }
        }
    }
    @ViewBuilder private func ppRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 16) { Image(systemName: icon).font(.system(size: 18)).foregroundColor(.eTextSoft).frame(width: 24); Text(label).font(EFont.body(15)).foregroundColor(.eText); Spacer(); Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.eTextMuted) }.padding(.horizontal, 16).padding(.vertical, 16) }
    }
}
