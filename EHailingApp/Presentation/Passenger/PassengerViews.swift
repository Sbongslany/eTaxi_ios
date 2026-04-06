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
            case .home:           PMainTabView(vm: vm)
            case .booking:        PBookingView(vm: vm)
            case .findingDriver:  PDriverMatchedView(vm: vm)
            case .inRide:         PInRideView(vm: vm)
            case .tripComplete:   PPaymentView(vm: vm)
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

// MARK: - Main Tab View with floating draggable tab bar (matching ZipRide)
struct PMainTabView: View {
    @ObservedObject var vm: PassengerViewModel
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch vm.selectedTab {
                case 0:  PHomeMapView(vm: vm)
                case 1:  PHistoryView(vm: vm)
                case 2:  PWalletView(vm: vm)
                default: PProfileView(vm: vm)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            PFloatingTabBar(vm: vm)
        }
        .background(Color.eBackground.ignoresSafeArea())
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Floating Draggable Tab Bar (ZipRide ZRTabBar)
struct PFloatingTabBar: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var offsetX: CGFloat = 0; @State private var savedOffsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0; @State private var savedOffsetY: CGFloat = 0
    @State private var isDragging = false
    private let barWidth: CGFloat = 280; private let barHeight: CGFloat = 64
    private let tabs = [("map", "map.fill", "Ride"), ("clock", "clock.fill", "History"),
                        ("creditcard", "creditcard.fill", "Wallet"), ("person", "person.fill", "Profile")]
    var body: some View {
        GeometryReader { geo in
            tabContent
                .frame(width: barWidth, height: barHeight)
                .position(x: clampX(offsetX + geo.size.width/2, in: geo),
                          y: clampY(offsetY + geo.size.height - 54, in: geo))
                .gesture(DragGesture(minimumDistance: 4)
                    .onChanged { val in isDragging = true; offsetX = savedOffsetX + val.translation.width; offsetY = savedOffsetY + val.translation.height }
                    .onEnded { _ in
                        isDragging = false; savedOffsetX = offsetX; savedOffsetY = offsetY
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            let cx = clampX(offsetX + geo.size.width/2, in: geo)
                            let cy = clampY(offsetY + geo.size.height - 54, in: geo)
                            offsetX = cx - geo.size.width/2; offsetY = cy - (geo.size.height - 54)
                        }
                    })
                .scaleEffect(isDragging ? 1.04 : 1.0).animation(.spring(response: 0.25), value: isDragging)
        }.ignoresSafeArea()
    }
    private func clampX(_ x: CGFloat, in geo: GeometryProxy) -> CGFloat { min(max(x, barWidth/2+12), geo.size.width-barWidth/2-12) }
    private func clampY(_ y: CGFloat, in geo: GeometryProxy) -> CGFloat { min(max(y, 100), geo.size.height-28) }
    @ViewBuilder private var tabContent: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                let (icon, filled, label) = tabs[i]; let sel = vm.selectedTab == i
                Button {
                    if !isDragging { withAnimation(.spring(response: 0.3)) { vm.selectedTab = i; if i==1 { Task { await vm.loadHistory() } } } }
                } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            if sel { Capsule().fill(Color.eGreen.opacity(0.18)).frame(width: 44, height: 28) }
                            Image(systemName: sel ? filled : icon).font(.system(size: 17, weight: sel ? .bold : .regular)).foregroundColor(sel ? .eGreen : .eTextMuted)
                        }
                        Text(label).font(.system(size: 9, weight: sel ? .bold : .medium)).foregroundColor(sel ? .eGreen : .eTextMuted)
                    }.frame(maxWidth: .infinity)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8).frame(height: barHeight)
        .background(ZStack { Capsule().fill(Color.eCard); Capsule().fill(.ultraThinMaterial).opacity(0.4) }.shadow(color: .black.opacity(0.45), radius: 24, y: 8))
        .overlay(Capsule().strokeBorder(LinearGradient(colors: [Color.eBorder.opacity(0.8), Color.eBorder.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }
}

// MARK: - Home Map View (ZipRide HomeMapView)
struct PHomeMapView: View {
    @ObservedObject var vm: PassengerViewModel
    @StateObject private var locMgr = LocationManager.shared
    @State private var region = MKCoordinateRegion(center: .init(latitude: -26.1076, longitude: 28.0567), span: .init(latitudeDelta: 0.04, longitudeDelta: 0.04))
    @State private var hasInitiallyCentred = false
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: vm.nearbyPins) { pin in
                MapAnnotation(coordinate: pin.coord) { ECarPin() }
            }.ignoresSafeArea()
            VStack(spacing: 0) {
                PHomeTopBar(vm: vm)
                Spacer()
                HStack {
                    Spacer()
                    Button { vm.syncPickup(); vm.screen = .customHire } label: {
                        HStack(spacing: 7) { Text("📅").font(.system(size: 17)); Text("Hire").font(EFont.body(13, weight: .bold)).foregroundColor(.white) }
                            .padding(.horizontal, 16).padding(.vertical, 11).background(Color(hex: "#6366F1")).clipShape(Capsule())
                            .shadow(color: Color(hex: "#6366F1").opacity(0.55), radius: 10, y: 4)
                    }.padding(.trailing, 16)
                }.padding(.bottom, 310)
            }
            PHomeBottomSheet(vm: vm)
        }
        .onAppear { locMgr.start() }
        .onChange(of: locMgr.coordinate) { coord in
            guard let coord else { return }
            if !hasInitiallyCentred || locMgr.accuracy < 50 {
                withAnimation(.easeInOut(duration: 1.2)) { region.center = coord; region.span = .init(latitudeDelta: 0.012, longitudeDelta: 0.012) }
                hasInitiallyCentred = true
            }
            vm.pickupCoord = coord; vm.pickupAddress = locMgr.address
        }
        .onChange(of: locMgr.address) { vm.pickupAddress = $0 }
        .task { await vm.loadServices() }
    }
}

struct PHomeTopBar: View {
    @ObservedObject var vm: PassengerViewModel
    @StateObject private var locMgr = LocationManager.shared
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 10)
            HStack {
                HStack(spacing: 0) {
                    Text("e").font(EFont.display(20, weight: .heavy)).foregroundColor(.eText)
                    Text("Taxi").font(EFont.display(20, weight: .heavy)).foregroundColor(.eGreen)
                }
                Spacer()
                Button { vm.selectedTab = 3 } label: {
                    ZStack {
                        Circle().fill(LinearGradient(colors: [.eGreen, Color(hex: "#00B85A")], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 38, height: 38)
                        Text(vm.user.initials).font(EFont.body(14, weight: .bold)).foregroundColor(.black)
                    }
                }
            }.padding(.horizontal, 20).padding(.vertical, 12)
            HStack(spacing: 8) {
                Circle().fill(Color.eGreen).frame(width: 8, height: 8)
                Text("📍 \(locMgr.address)").font(EFont.body(13)).foregroundColor(.eTextSoft).lineLimit(1)
                Spacer()
                if locMgr.accuracy < 999 && locMgr.accuracy > 20 { Text("±\(Int(locMgr.accuracy))m").font(EFont.body(10)).foregroundColor(.eTextMuted) }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.eCard.opacity(0.92)).overlay(RoundedRectangle(cornerRadius: 100).stroke(Color.eBorder, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 100))
            .padding(.horizontal, 20).padding(.bottom, 10)
        }
        .background(LinearGradient(colors: [Color.eBackground.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom))
    }
}

struct PHomeBottomSheet: View {
    @ObservedObject var vm: PassengerViewModel
    @StateObject private var locMgr = LocationManager.shared
    var timeOfDay: String { let h = Calendar.current.component(.hour, from: Date()); return h < 12 ? "morning" : h < 17 ? "afternoon" : "evening" }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ESheetHandle().padding(.top, 12).padding(.bottom, 18)
            Text("Good \(timeOfDay), \(vm.user.firstName) 👋").font(EFont.body(13)).foregroundColor(.eTextSoft).padding(.bottom, 4)
            Text("Where to?").font(EFont.display(22, weight: .bold)).foregroundColor(.eText).kerning(-0.5).padding(.bottom, 14)
            Button {
                setPickup(); vm.dropoffAddress = ""; vm.dropoffCoord = nil; vm.estimates = [:]; vm.screen = .booking
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .semibold)).foregroundColor(.eGreen)
                    Text("Search destination…").font(EFont.body(15)).foregroundColor(.eTextMuted); Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 15).background(Color.eSurface)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.eBorder, lineWidth: 1.5)).clipShape(RoundedRectangle(cornerRadius: 13))
            }.padding(.bottom, 12)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PopularPlace.all.prefix(4)) { p in
                        PQuickChip(emoji: p.emoji, label: p.name).onTapGesture { setPickup(); vm.setPopular(p); vm.screen = .booking }
                    }
                }
            }.padding(.bottom, 18)
            if !vm.tripHistory.isEmpty {
                Text("RECENT PLACES").font(EFont.body(11, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.8).padding(.bottom, 10)
                VStack(spacing: 0) {
                    ForEach(Array(vm.tripHistory.prefix(2).enumerated()), id: \.element.id) { idx, trip in
                        HStack(spacing: 12) {
                            ZStack { RoundedRectangle(cornerRadius: 10).fill(Color.eSurface).frame(width: 38, height: 38); Text("📍").font(.system(size: 16)) }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.dropoffAddress).font(EFont.body(14)).foregroundColor(.eText).lineLimit(1)
                                Text(trip.pickupAddress).font(EFont.body(12)).foregroundColor(.eTextMuted).lineLimit(1)
                            }; Spacer()
                        }.padding(.vertical, 11)
                        .onTapGesture { setPickup(); vm.dropoffAddress = trip.dropoffAddress; vm.estimates = [:]
                            geocode(trip.dropoffAddress) { c in vm.dropoffCoord = c; Task { await vm.fetchEstimates() }; vm.screen = .booking }
                        }
                        if idx == 0 { Divider().background(Color.eBorder) }
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 88)
        .background(Color.eCard).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.eBorder, lineWidth: 1) }
    }
    private func setPickup() {
        if let c = locMgr.coordinate { vm.pickupCoord = c; vm.pickupAddress = locMgr.address.isEmpty ? "Current Location" : locMgr.address }
    }
}

struct PQuickChip: View {
    let emoji: String; let label: String
    var body: some View {
        HStack(spacing: 6) { Text(emoji).font(.system(size: 15)); Text(label).font(EFont.body(13)).foregroundColor(.eText) }
            .padding(.horizontal, 14).padding(.vertical, 8).background(Color.eSurface)
            .overlay(RoundedRectangle(cornerRadius: 100).stroke(Color.eBorder, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 100))
    }
}

// MARK: - Booking View
struct PBookingView: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var isSearching = true
    var body: some View {
        ZStack(alignment: .bottom) {
            PBookingMapView(pickup: vm.pickupCoord, dropoff: vm.dropoffCoord).ignoresSafeArea()
            VStack { HStack {
                Button { vm.screen = .home } label: {
                    ZStack { RoundedRectangle(cornerRadius: 10).fill(Color.eCard.opacity(0.92)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.eBorder, lineWidth: 1)); Image(systemName: "arrow.left").font(.system(size: 15, weight: .semibold)).foregroundColor(.eText) }.frame(width: 38, height: 38)
                }; Spacer()
            }.padding(.horizontal, 16).padding(.top, 54); Spacer() }
            if isSearching { PSearchSheet(vm: vm, isSearching: $isSearching) }
            else           { PLiveBookingSheet(vm: vm, onEdit: { isSearching = true }) }
        }
        .ignoresSafeArea()
        .onAppear { isSearching = vm.dropoffAddress.isEmpty }
        // Removed: was auto-dismissing search sheet before user could confirm
    }
}

struct PBookingMapView: UIViewRepresentable {
    var pickup: CLLocationCoordinate2D?; var dropoff: CLLocationCoordinate2D?
    func makeUIView(context: Context) -> MKMapView {
        let m = MKMapView(); m.delegate = context.coordinator; m.showsUserLocation = true; m.userTrackingMode = .follow; m.showsCompass = false; return m
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let co = context.coordinator
        guard pickup?.latitude != co.lp?.latitude || dropoff?.latitude != co.ld?.latitude else { return }
        co.lp = pickup; co.ld = dropoff
        map.removeOverlays(map.overlays); map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
        if let p = pickup { let a = PColoredPin(coordinate: p, title: "Pickup", isPickup: true); map.addAnnotation(a) }
        if let d = dropoff { let a = PColoredPin(coordinate: d, title: "Drop-off", isPickup: false); map.addAnnotation(a) }
        if let p = pickup, let d = dropoff {
            let req = MKDirections.Request(); req.transportType = .automobile
            req.source = MKMapItem(placemark: MKPlacemark(coordinate: p)); req.destination = MKMapItem(placemark: MKPlacemark(coordinate: d))
            MKDirections(request: req).calculate { resp, _ in DispatchQueue.main.async {
                guard let r = resp?.routes.first else { return }
                map.addOverlay(r.polyline, level: .aboveRoads)
                map.setVisibleMapRect(r.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 420, right: 40), animated: true)
            }}
        } else if let p = pickup { map.setRegion(.init(center: p, span: .init(latitudeDelta: 0.012, longitudeDelta: 0.012)), animated: true) }
    }
    func makeCoordinator() -> Coord { Coord() }
    final class Coord: NSObject, MKMapViewDelegate {
        var lp: CLLocationCoordinate2D?; var ld: CLLocationCoordinate2D?
        func mapView(_ m: MKMapView, rendererFor o: MKOverlay) -> MKOverlayRenderer {
            let r = MKPolylineRenderer(overlay: o); r.strokeColor = UIColor(red:0,green:0.9,blue:0.46,alpha:1); r.lineWidth = 5; r.lineCap = .round; return r
        }
        func mapView(_ m: MKMapView, viewFor a: MKAnnotation) -> MKAnnotationView? {
            guard let pin = a as? PColoredPin else { return nil }
            let id = pin.isPickup ? "pickup" : "dropoff"
            let v  = (m.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView) ?? MKMarkerAnnotationView(annotation: pin, reuseIdentifier: id)
            v.annotation = pin; v.canShowCallout = true
            v.glyphImage = UIImage(systemName: pin.isPickup ? "circle.fill" : "flag.fill")
            v.markerTintColor = pin.isPickup ? UIColor(red:0,green:0.9,blue:0.46,alpha:1) : UIColor(red:1,green:0.6,blue:0,alpha:1); return v
        }
    }
}
final class PColoredPin: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D; let title: String?; let isPickup: Bool
    init(coordinate: CLLocationCoordinate2D, title: String, isPickup: Bool) { self.coordinate=coordinate; self.title=title; self.isPickup=isPickup }
}

// MARK: - Search Destination Sheet (ZipRide SearchDestinationSheet)
struct PSearchSheet: View {
    @ObservedObject var vm: PassengerViewModel
    @Binding var isSearching: Bool
    @StateObject private var locMgr = LocationManager.shared
    @State private var activeField = "dropoff"; @State private var pickupText = ""; @State private var dropoffText = ""
    @State private var results: [MKMapItem] = []; @State private var search: MKLocalSearch?
    @FocusState private var pFocus: Bool; @FocusState private var dFocus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ESheetHandle().padding(.top, 12).padding(.bottom, 14)
            Text("Plan your trip").font(EFont.display(20, weight: .heavy)).foregroundColor(.eText).padding(.horizontal, 20).padding(.bottom, 16)

            VStack(spacing: 0) {
                // Pickup
                HStack(spacing: 12) {
                    ZStack { Circle().fill(Color.eGreen).frame(width: 12, height: 12); if activeField == "pickup" { Circle().stroke(Color.eGreen, lineWidth: 2).frame(width: 20, height: 20) } }.frame(width: 20)
                    TextField(vm.pickupAddress.isEmpty ? "Current location" : vm.pickupAddress, text: $pickupText)
                        .font(EFont.body(14, weight: activeField == "pickup" ? .semibold : .regular))
                        .foregroundColor(activeField == "pickup" ? .eText : .eTextSoft).tint(.eGreen).focused($pFocus)
                        .onChange(of: pFocus) { focused in
                            if focused {
                                activeField = "pickup"; dFocus = false
                                // Always sync with latest vm value when field gains focus
                                pickupText = vm.pickupAddress
                            }
                        }
                        .onChange(of: pickupText) { if activeField == "pickup" { runSearch($0) } }
                    if activeField == "pickup" && !pickupText.isEmpty {
                        Button {
                            pickupText = ""; results = []
                            vm.pickupAddress    = ""; vm.pickupCoord = nil
                            vm.userHasSetPickup = false  // allow GPS again
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.eTextMuted).font(.system(size: 16))
                        }
                    }
                }.padding(.horizontal, 16).padding(.vertical, 13)

                // Swap
                HStack {
                    Rectangle().fill(Color.eBorder).frame(width: 1, height: 20).padding(.leading, 25); Spacer()
                    Button {
                        // Swap vm state
                        let tmpAddr  = vm.pickupAddress;  let tmpCoord = vm.pickupCoord
                        vm.pickupAddress  = vm.dropoffAddress; vm.pickupCoord  = vm.dropoffCoord
                        vm.dropoffAddress = tmpAddr;           vm.dropoffCoord = tmpCoord
                        // Sync local text fields immediately
                        pickupText  = vm.pickupAddress
                        dropoffText = vm.dropoffAddress
                        results     = []
                        // Refetch estimates with swapped coords
                        Task { await vm.fetchEstimates() }
                    } label: { ZStack { Circle().fill(Color.eSurface).frame(width: 28, height: 28).overlay(Circle().stroke(Color.eBorder, lineWidth: 1)); Image(systemName: "arrow.up.arrow.down").font(.system(size: 11, weight: .bold)).foregroundColor(.eTextMuted) } }
                    .padding(.trailing, 16)
                }
                Rectangle().fill(Color.eBorder).frame(height: 0.5).padding(.leading, 48)

                // Dropoff
                HStack(spacing: 12) {
                    ZStack { RoundedRectangle(cornerRadius: 3).fill(Color.eAccent).frame(width: 12, height: 12); if activeField=="dropoff" { RoundedRectangle(cornerRadius: 4).stroke(Color.eAccent, lineWidth: 2).frame(width: 20, height: 20) } }.frame(width: 20)
                    TextField("Search destination…", text: $dropoffText)
                        .font(EFont.body(14, weight: activeField=="dropoff" ? .semibold : .regular))
                        .foregroundColor(activeField=="dropoff" ? .eText : .eTextSoft).tint(.eGreen).focused($dFocus)
                        .onChange(of: dFocus) { focused in
                            if focused {
                                activeField = "dropoff"; pFocus = false
                                // Sync with latest vm value when field gains focus
                                if dropoffText.isEmpty { dropoffText = vm.dropoffAddress }
                            }
                        }
                        .onChange(of: dropoffText) { if activeField == "dropoff" { runSearch($0) } }
                    if activeField == "dropoff" && !dropoffText.isEmpty {
                        Button {
                            dropoffText = ""; results = []
                            vm.dropoffAddress = ""; vm.dropoffCoord = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.eTextMuted).font(.system(size: 16))
                        }
                    }
                }.padding(.horizontal, 16).padding(.vertical, 13)
            }
            .background(Color.eSurface)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(activeField=="pickup" ? Color.eGreen.opacity(0.5) : Color.eAccent.opacity(0.5), lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 20).padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if !results.isEmpty {
                        ForEach(results, id: \.self) { item in
                            Button { selectItem(item) } label: {
                                HStack(spacing: 14) {
                                    ZStack { RoundedRectangle(cornerRadius: 8).fill(Color.eSurface).frame(width: 36, height: 36); Image(systemName: activeField=="pickup" ? "location.fill" : "mappin.circle.fill").font(.system(size: 15)).foregroundColor(activeField=="pickup" ? .eGreen : .eAccent) }
                                    VStack(alignment: .leading, spacing: 2) { Text(item.name ?? "").font(EFont.body(14, weight: .semibold)).foregroundColor(.eText).lineLimit(1); Text(item.placemark.title ?? "").font(EFont.body(12)).foregroundColor(.eTextMuted).lineLimit(1) }; Spacer()
                                }.padding(.horizontal, 20).padding(.vertical, 12)
                            }
                            Divider().padding(.leading, 70)
                        }
                    } else { quickPicks }
                }
            }
            // Confirm button — only shown when both fields are set
            if !vm.dropoffAddress.isEmpty && !vm.pickupAddress.isEmpty {
                VStack(spacing: 8) {
                    Divider().background(Color.eBorder)
                    Button {
                        isSearching = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Confirm destination").font(EFont.body(15, weight: .bold))
                                Text(vm.dropoffAddress).font(EFont.body(11)).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color.eGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16).padding(.bottom, 12)
                }
            } else {
                Spacer(minLength: 20)
            }
        }
        .background(Color.eCard).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.eBorder, lineWidth: 1) }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.78)
        .onAppear {
            // Sync once on appear only — do NOT keep syncing (would override user edits)
            pickupText  = vm.pickupAddress
            dropoffText = vm.dropoffAddress
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if vm.dropoffAddress.isEmpty { dFocus = true }
            }
        }
    }

    @ViewBuilder private var quickPicks: some View {
        Text(activeField == "pickup" ? "NEARBY PLACES" : "POPULAR DESTINATIONS")
            .font(EFont.body(10, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.8)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 8)
        let places: [(String, String, String)] = activeField == "pickup"
            ? [("📍","Current Location","Use GPS"),("🏠","Home","12 Elm Rd, Fourways"),("💼","Work","14 Fredman Dr, Sandton")]
            : PopularPlace.all.map { ($0.emoji, $0.name, $0.address) }
        ForEach(places, id: \.1) { emoji, label, addr in
            Button { selectPlace(emoji: emoji, label: label, address: addr) } label: {
                HStack(spacing: 14) {
                    ZStack { RoundedRectangle(cornerRadius: 8).fill(Color.eSurface).frame(width: 36, height: 36); Text(emoji).font(.system(size: 16)) }
                    VStack(alignment: .leading, spacing: 2) { Text(label).font(EFont.body(14)).foregroundColor(.eText); Text(addr).font(EFont.body(12)).foregroundColor(.eTextMuted).lineLimit(1) }; Spacer()
                }.padding(.horizontal, 20).padding(.vertical, 11)
            }
            Divider().padding(.leading, 70)
        }
    }

    private func selectItem(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        let name  = item.name ?? item.placemark.title ?? "Location"
        let field = activeField  // capture before any async

        if field == "pickup" {
            // User selected a new pickup location — lock out GPS overwrite
            vm.pickupAddress    = name
            vm.pickupCoord      = coord
            vm.userHasSetPickup = true
            pickupText          = name
            results             = []
            // Move focus to dropoff — stay in search sheet
            activeField = "dropoff"; pFocus = false; dFocus = true
        } else {
            // User selected destination
            vm.dropoffAddress = name
            vm.dropoffCoord   = coord
            dropoffText       = name
            results           = []
            // Only use GPS for pickup if user hasn't manually set one
            if vm.pickupCoord == nil, let gps = locMgr.coordinate {
                vm.pickupCoord   = gps
                vm.pickupAddress = locMgr.address
                pickupText       = locMgr.address
            }
            Task { await vm.fetchEstimates() }
        }
    }
    private func selectPlace(emoji: String, label: String, address: String) {
        // Capture activeField NOW (before async geocode)
        let fieldAtCallTime = activeField

        if fieldAtCallTime == "pickup" && label == "Current Location" {
            if let c = locMgr.coordinate {
                vm.pickupCoord = c; vm.pickupAddress = locMgr.address; pickupText = locMgr.address
            }
            activeField = "dropoff"; pFocus = false; dFocus = true
        } else {
            geocode(address) { c in
                guard let c else { return }
                if fieldAtCallTime == "pickup" {
                    vm.pickupAddress    = label
                    vm.pickupCoord      = c
                    vm.userHasSetPickup = true
                    pickupText = label; results = []
                    activeField = "dropoff"; pFocus = false; dFocus = true
                } else {
                    vm.dropoffAddress = label; vm.dropoffCoord = c
                    dropoffText = label; results = []
                    if vm.pickupCoord == nil, let gps = locMgr.coordinate {
                        vm.pickupCoord = gps
                        vm.pickupAddress = locMgr.address
                        pickupText = locMgr.address
                    }
                    Task { await vm.fetchEstimates() }
                }
            }
        }
    }
    private func ensurePickup() { if vm.pickupCoord==nil, let c=locMgr.coordinate { vm.pickupCoord=c; vm.pickupAddress=locMgr.address } }
    private func runSearch(_ q: String) {
        search?.cancel(); search=nil; guard q.count>1 else { results=[]; return }
        let req=MKLocalSearch.Request(); req.naturalLanguageQuery=q+" South Africa"
        req.region=MKCoordinateRegion(center: locMgr.coordinate ?? .init(latitude:-26.1076,longitude:28.0567), span: .init(latitudeDelta:1.5,longitudeDelta:1.5))
        let s=MKLocalSearch(request: req); search=s
        s.start { resp,_ in DispatchQueue.main.async { self.results=resp?.mapItems.prefix(8).map{$0} ?? [] } }
    }
}

// MARK: - Live Booking Sheet (ZipRide LiveBookingSheet)
struct PLiveBookingSheet: View {
    @ObservedObject var vm: PassengerViewModel; var onEdit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ESheetHandle().padding(.top, 12).padding(.bottom, 16)
            // Route summary
            VStack(spacing: 0) {
                PTripSummaryRow(dotColor: .eGreen, text: vm.pickupAddress.isEmpty ? "Current Location" : vm.pickupAddress)
                Rectangle().fill(Color.eBorder).frame(width: 1, height: 14).padding(.leading, 4)
                Button(action: onEdit) { PTripSummaryRow(dotColor: .eAccent, text: vm.dropoffAddress.isEmpty ? "Tap to set destination…" : vm.dropoffAddress) }
            }.padding(14).background(Color.eSurface).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.eBorder, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.bottom, 18)

            Text("CHOOSE SERVICE").font(EFont.body(11, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.8).padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    if vm.standardServices.isEmpty { ForEach(0..<3,id:\.self){_ in RoundedRectangle(cornerRadius:16).fill(Color.eSurface).frame(height:72).overlay(ProgressView().tint(.eGreen))} }
                    else { ForEach(vm.standardServices) { svc in PLiveServiceCard(vm: vm, service: svc) } }
                }.padding(.bottom, 16)
            }.frame(maxHeight: 260)

            PPPaymentBar().padding(.bottom, 14)
            if let err = vm.errorMessage { Text(err).font(EFont.body(13)).foregroundColor(.eRed).padding(.bottom, 8) }
            if let svc = vm.selectedService {
                HStack(spacing: 6) { Image(systemName: svc.isCustomHire ? "clock.fill" : "bolt.fill").font(.system(size: 11)); Text(svc.isCustomHire ? "Custom Hire" : "Standard Ride").font(EFont.body(11, weight: .bold)); Spacer() }
                    .foregroundColor(svc.isCustomHire ? Color(hex:"#6366F1") : .eGreen)
                    .padding(.horizontal,12).padding(.vertical,8).background((svc.isCustomHire ? Color(hex:"#6366F1") : Color.eGreen).opacity(0.08))
                    .overlay(Capsule().stroke((svc.isCustomHire ? Color(hex:"#6366F1") : Color.eGreen).opacity(0.2),lineWidth:1)).clipShape(Capsule()).padding(.bottom,8)
            }
            Button { vm.confirmRide() } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(vm.isLoading ? Color.eGreen.opacity(0.5) : Color.eGreen)
                    if vm.isLoading { ProgressView().tint(.black) }
                    else { Text("Confirm  ·  \(vm.selectedFare.map { "R\(Int($0))" } ?? "R—")").font(EFont.body(16, weight: .bold)).foregroundColor(.black) }
                }.frame(maxWidth: .infinity).frame(height: 56)
            }.disabled(vm.isLoading || vm.dropoffAddress.isEmpty)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20).padding(.bottom, 36)
        .background(Color.eCard).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.eBorder, lineWidth: 1) }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.70)
        .task { await vm.loadServices(); if vm.estimates.isEmpty { await vm.fetchEstimates() } }
    }
}

struct PTripSummaryRow: View {
    let dotColor: Color; let text: String
    var body: some View { HStack(spacing: 12) { Circle().fill(dotColor).frame(width: 10, height: 10); Text(text).font(EFont.body(13)).foregroundColor(.eText) }.padding(.vertical, 5) }
}

struct PLiveServiceCard: View {
    @ObservedObject var vm: PassengerViewModel; let service: BERideService
    var isSelected: Bool { vm.selectedService?.id == service.id }
    var est: EstimateResponse? { vm.estimates[service.key] }
    var livePrice: String { est.flatMap { $0.estimated ?? $0.min }.map { "R\(Int($0))" } ?? service.displayPrice }
    var liveETA:   String { est?.durationMin.map { "\(Int($0)) min" } ?? "— min" }
    var body: some View {
        Button { withAnimation(.spring(response: 0.3)) { vm.selectedService = service }; Task { await vm.fetchEstimates() } } label: {
            HStack(spacing: 14) {
                Text(service.emoji).font(.system(size: 30)).frame(width: 68, height: 46)
                VStack(alignment: .leading, spacing: 3) { Text(service.name).font(EFont.display(15, weight: .bold)).foregroundColor(.eText); Text("\(service.maxPassengers) seats · \(service.vehicleType.capitalized)").font(EFont.body(12)).foregroundColor(.eTextSoft) }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    if est == nil && isSelected { ProgressView().tint(.eGreen).scaleEffect(0.7) }
                    else { Text(livePrice).font(EFont.display(18, weight: .heavy)).foregroundColor(.eText); Text(liveETA).font(EFont.body(11)).foregroundColor(.eTextSoft) }
                }
            }.padding(14)
            .background(isSelected ? Color.eGreen.opacity(0.05) : Color.eSurface)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.eGreen : Color.eBorder, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .topTrailing) { if isSelected { ZStack { Circle().fill(Color.eGreen).frame(width: 20, height: 20); Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundColor(.black) }.offset(x: -10, y: 10) } }
        }
    }
}

struct PPPaymentBar: View {
    @State private var showPicker = false; @State private var method = "cash"
    var body: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 10) {
                ZStack { RoundedRectangle(cornerRadius: 8).fill(Color.eBackground).frame(width: 32, height: 32); Image(systemName: method=="cash" ? "banknote.fill" : "creditcard.fill").font(.system(size: 14)).foregroundColor(method=="cash" ? .eAccent : .eGreen) }
                VStack(alignment: .leading, spacing: 2) { Text(method=="cash" ? "Cash Payment" : "Card Payment").font(EFont.body(13, weight: .semibold)).foregroundColor(.eText); Text(method=="cash" ? "Pay driver directly" : "Pay by card on completion").font(EFont.body(11)).foregroundColor(.eTextSoft) }
                Spacer(); Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold)).foregroundColor(.eTextMuted)
            }.padding(.horizontal,16).padding(.vertical,12).background(Color.eSurface).overlay(RoundedRectangle(cornerRadius:13).stroke(Color.eBorder,lineWidth:1)).clipShape(RoundedRectangle(cornerRadius:13))
        }
        .confirmationDialog("Payment Method", isPresented: $showPicker, titleVisibility: .visible) {
            Button("💳  Card Payment") { method="card" }; Button("💵  Cash Payment") { method="cash" }; Button("Cancel", role: .cancel) {}
        } message: { Text("How would you like to pay?") }
    }
}

// MARK: - Driver Matched View (ZipRide DriverMatchedView + LiveDriverMatchedSheet)
struct PDriverMatchedView: View {
    @ObservedObject var vm: PassengerViewModel
    @StateObject private var locMgr = LocationManager.shared
    var pickupCoord: CLLocationCoordinate2D? {
        guard let t = vm.currentTrip else { return locMgr.coordinate }
        return CLLocationCoordinate2D(latitude: t.pickupLat, longitude: t.pickupLon)
    }
    var body: some View {
        ZStack(alignment: .bottom) {
            ETaxiMap(origin: vm.driverCoord ?? locMgr.coordinate, target: pickupCoord, isPickup: true, fitRoute: false, eta: $vm.mapEta, distance: $vm.mapDist, traffic: $vm.mapTraffic).ignoresSafeArea()
            PLiveDriverMatchedSheet(vm: vm)
        }.ignoresSafeArea()
    }
}

struct PLiveDriverMatchedSheet: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var elapsed = 0; @State private var timer: Timer?
    private let timeout = 60
    var body: some View {
        if vm.currentTrip == nil && !vm.searchTimedOut { Color.clear.onAppear { vm.screen = .home } }
        else if vm.searchTimedOut { PNoDriverSheet(vm: vm) }
        else { searchingSheet }
    }
    private var searchingSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            ESheetHandle().padding(.top, 12).padding(.bottom, 16)
            // Status pill
            HStack(spacing: 6) {
                if vm.currentTrip?.driverName == nil { ProgressView().tint(.eGreen).scaleEffect(0.7); Text(vm.currentTrip?.statusLabel ?? "Finding driver…").font(EFont.body(12, weight: .bold)).foregroundColor(.eGreen); Spacer(); Text("\(max(0,timeout-elapsed))s").font(EFont.body(12, weight: .bold)).foregroundColor(.eTextMuted) }
                else { Circle().fill(Color.eGreen).frame(width: 6, height: 6); Text(vm.currentTrip?.statusLabel ?? "Driver on the way").font(EFont.body(12, weight: .bold)).foregroundColor(.eGreen) }
            }.padding(.horizontal,14).padding(.vertical,7).background(Color.eGreen.opacity(0.08)).overlay(Capsule().stroke(Color.eGreen.opacity(0.2),lineWidth:1)).clipShape(Capsule()).padding(.bottom,16)
            // Countdown
            if vm.currentTrip?.driverName == nil {
                GeometryReader { geo in ZStack(alignment: .leading) { RoundedRectangle(cornerRadius:3).fill(Color.eBorder).frame(height:3); RoundedRectangle(cornerRadius:3).fill(elapsed>45 ? Color.eRed : Color.eGreen).frame(width: geo.size.width*CGFloat(elapsed)/CGFloat(timeout), height:3).animation(.linear(duration:1), value:elapsed) } }.frame(height:3).padding(.bottom,14)
            }
            // Driver card
            if let name = vm.currentTrip?.driverName {
                HStack(spacing: 14) {
                    ZStack { Circle().fill(LinearGradient(colors:[Color(hex:"#1C2535"),Color(hex:"#252B38")],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:60,height:60).overlay(Circle().stroke(Color.eBorder,lineWidth:2)); Text("👨🏾").font(.system(size:28)) }
                    VStack(alignment: .leading, spacing: 4) { Text(name).font(EFont.display(18, weight: .bold)).foregroundColor(.eText); if let c=vm.currentTrip?.driverCode { Text("Code: \(c)").font(EFont.body(12)).foregroundColor(.eTextMuted) } }
                    Spacer()
                    if let v=vm.currentTrip?.vehicleInfo { Text(v).font(EFont.display(13,weight:.heavy)).foregroundColor(.eBackground).padding(.horizontal,10).padding(.vertical,6).background(Color.eText).clipShape(RoundedRectangle(cornerRadius:8)) }
                }.padding(.bottom,18)
            } else { HStack(spacing:12){ProgressView().tint(.eGreen); Text("Connecting you with a driver…").font(EFont.body(14)).foregroundColor(.eTextSoft)}.padding(.bottom,18) }
            // ETA+fare
            // ETA + distance + fare — with traffic indicator
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ARRIVING IN").font(EFont.body(10, weight: .bold)).foregroundColor(.eTextSoft).kerning(0.5)
                        Text(vm.mapEta).font(EFont.display(26, weight: .heavy)).foregroundColor(.eGreen)
                        Text(vm.mapDist).font(EFont.body(11)).foregroundColor(.eTextMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Rectangle().fill(Color.eBorder).frame(width: 1, height: 48)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("FARE").font(EFont.body(10, weight: .bold)).foregroundColor(.eTextSoft).kerning(0.5)
                        Text(vm.currentTrip?.fareStr ?? "R0").font(EFont.display(22, weight: .heavy)).foregroundColor(.eText)
                        if let km = vm.currentTrip?.estimatedDistanceKm {
                            Text(String(format: "%.1f km", km)).font(EFont.body(11)).foregroundColor(.eTextMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 18).padding(.vertical, 14).background(Color.eSurface)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(
                    vm.mapTraffic == .heavy ? Color.eRed.opacity(0.5) :
                    vm.mapTraffic == .moderate ? Color.eAccent.opacity(0.5) : Color.eBorder, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 13))

                if vm.mapTraffic == .heavy || vm.mapTraffic == .moderate {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                            .foregroundColor(vm.mapTraffic == .heavy ? .eRed : .eAccent)
                        Text(vm.mapTraffic == .heavy ? "Heavy traffic on route" : "Slow traffic ahead")
                            .font(EFont.body(12, weight: .semibold))
                            .foregroundColor(vm.mapTraffic == .heavy ? .eRed : .eAccent)
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background((vm.mapTraffic == .heavy ? Color.eRed : Color.eAccent).opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }.padding(.bottom, 14)
            // Actions
            HStack(spacing: 10) { PDriverActionBtn(icon:"phone.fill",label:"Call"); PDriverActionBtn(icon:"message.fill",label:"Chat"); PDriverActionBtn(icon:"square.and.arrow.up",label:"Share",tint:.eGreen) }.padding(.bottom,14)
            if vm.currentTrip?.canCancel==true || vm.currentTrip?.status=="searching" {
                Button { vm.cancelRide() } label: { Text("Cancel Ride").font(EFont.body(14,weight:.semibold)).foregroundColor(.eRed).frame(maxWidth:.infinity).padding(.vertical,16).overlay(RoundedRectangle(cornerRadius:16).stroke(Color.eBorder,lineWidth:1.5)) }
            }
        }
        .padding(.horizontal,20).padding(.bottom,40).background(Color.eCard).clipShape(RoundedRectangle(cornerRadius:28,style:.continuous))
        .overlay(alignment:.top){RoundedRectangle(cornerRadius:28,style:.continuous).stroke(Color.eBorder,lineWidth:1)}
        .onAppear { elapsed=0; timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true){_ in elapsed+=1} }
        .onDisappear { timer?.invalidate() }
    }
}

struct PNoDriverSheet: View {
    @ObservedObject var vm: PassengerViewModel
    var body: some View {
        VStack(spacing: 0) {
            ESheetHandle().padding(.top,12).padding(.bottom,20)
            Image(systemName:"car.fill").font(.system(size:40)).foregroundColor(.eTextMuted.opacity(0.4)).padding(.bottom,12)
            Text("No Drivers Available").font(EFont.display(20,weight:.heavy)).foregroundColor(.eText)
            Text("We couldn't find a driver nearby.\nTry again in a few minutes.").font(EFont.body(14)).foregroundColor(.eTextSoft).multilineTextAlignment(.center).lineSpacing(4).padding(.horizontal,30).padding(.top,6).padding(.bottom,28)
            VStack(spacing: 10) {
                Button { vm.retryRide() } label: { HStack(spacing:8){Image(systemName:"arrow.clockwise").font(.system(size:14,weight:.bold));Text("Try Again").font(EFont.body(16,weight:.bold))}.foregroundColor(.black).frame(maxWidth:.infinity).frame(height:52).background(Color.eGreen).clipShape(RoundedRectangle(cornerRadius:16)) }
                Button { vm.dismissNoDriver() } label: { Text("Back to Home").font(EFont.body(15,weight:.semibold)).foregroundColor(.eTextMuted).frame(maxWidth:.infinity).frame(height:48).background(Color.eSurface).overlay(RoundedRectangle(cornerRadius:16).stroke(Color.eBorder,lineWidth:1.5)).clipShape(RoundedRectangle(cornerRadius:16)) }
            }.padding(.horizontal,20).padding(.bottom,48)
        }
        .background(Color.eCard).clipShape(RoundedRectangle(cornerRadius:28,style:.continuous))
        .overlay(alignment:.top){RoundedRectangle(cornerRadius:28,style:.continuous).stroke(Color.eBorder,lineWidth:1)}
    }
}

struct PDriverActionBtn: View {
    let icon: String; let label: String; var tint: Color = .eText
    var body: some View {
        Button {} label: {
            HStack(spacing:8){Image(systemName:icon).font(.system(size:14,weight:.semibold));Text(label).font(EFont.body(13,weight:.semibold))}
                .foregroundColor(tint).frame(maxWidth:.infinity).padding(.vertical,14).background(Color.eSurface)
                .overlay(RoundedRectangle(cornerRadius:13).stroke(Color.eBorder,lineWidth:1.5)).clipShape(RoundedRectangle(cornerRadius:13))
        }
    }
}

// MARK: - In Ride View (ZipRide InRideView + LiveInRideSheet)
struct PInRideView: View {
    @ObservedObject var vm: PassengerViewModel
    @StateObject private var locMgr = LocationManager.shared
    var dropoffCoord: CLLocationCoordinate2D? {
        guard let t = vm.currentTrip else { return nil }
        return CLLocationCoordinate2D(latitude: t.dropoffLat, longitude: t.dropoffLon)
    }
    var body: some View {
        ZStack(alignment: .bottom) {
            ETaxiMap(origin: vm.driverCoord ?? locMgr.coordinate, target: dropoffCoord, isPickup: false, fitRoute: false, eta: $vm.mapEta, distance: $vm.mapDist, traffic: $vm.mapTraffic).ignoresSafeArea()
            VStack { PInRideBar(eta: vm.mapEta, dist: vm.mapDist, trip: vm.currentTrip).padding(.horizontal,16).padding(.top,54); Spacer() }
            PLiveInRideSheet(vm: vm)
        }.ignoresSafeArea()
    }
}

struct PInRideBar: View {
    let eta: String; let dist: String; let trip: BETrip?
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment:.leading,spacing:2){Text("ARRIVING IN").font(EFont.body(10,weight:.bold)).foregroundColor(.eTextSoft).kerning(0.5);Text(eta).font(EFont.display(18,weight:.heavy)).foregroundColor(.eGreen)}
            Spacer()
            VStack(alignment:.trailing,spacing:2){Text("REMAINING").font(EFont.body(10,weight:.bold)).foregroundColor(.eTextSoft).kerning(0.5);Text(dist).font(EFont.body(14,weight:.semibold)).foregroundColor(.eText)}
            Spacer()
            VStack(alignment:.trailing,spacing:2){Text("FARE").font(EFont.body(10,weight:.bold)).foregroundColor(.eTextSoft).kerning(0.5);Text(trip?.fareStr ?? "R0").font(EFont.display(18,weight:.heavy)).foregroundColor(.eText)}
        }
        .padding(.horizontal,18).padding(.vertical,12)
        .background(ZStack{RoundedRectangle(cornerRadius:14).fill(Color.eCard);RoundedRectangle(cornerRadius:14).fill(.ultraThinMaterial).opacity(0.3)}.shadow(color:.black.opacity(0.3),radius:10,y:3))
        .overlay(RoundedRectangle(cornerRadius:14).stroke(Color.eBorder.opacity(0.6),lineWidth:1))
    }
}

struct PLiveInRideSheet: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var showCancel = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ESheetHandle().padding(.top,12).padding(.bottom,8)
            HStack {
                HStack(spacing:6){Circle().fill(Color.eGreen).frame(width:6,height:6);Text("In Progress").font(EFont.body(12,weight:.bold)).foregroundColor(.eGreen)}.padding(.horizontal,12).padding(.vertical,6).background(Color.eGreen.opacity(0.08)).overlay(Capsule().stroke(Color.eGreen.opacity(0.2),lineWidth:1)).clipShape(Capsule())
                Spacer(); Text(vm.currentTrip?.fareStr ?? "R0").font(EFont.display(18,weight:.heavy)).foregroundColor(.eGreen)
            }.padding(.bottom,14)
            if let name = vm.currentTrip?.driverName {
                HStack(spacing:14){
                    ZStack{Circle().fill(Color.eSurface).frame(width:44,height:44).overlay(Circle().stroke(Color.eBorder,lineWidth:1.5));Text("👨🏾").font(.system(size:22))}
                    VStack(alignment:.leading,spacing:3){Text(name).font(EFont.body(14,weight:.bold)).foregroundColor(.eText);if let v=vm.currentTrip?.vehicleInfo{Text(v).font(EFont.body(11)).foregroundColor(.eTextMuted)}}
                    Spacer()
                }.padding(.bottom,12)
            }
            // Route card with full addresses
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(spacing: 0) {
                        Circle().fill(Color.eGreen).frame(width: 10, height: 10)
                        Rectangle().fill(Color.eBorder).frame(width: 1, height: 24)
                        Circle().fill(Color.eAccent).frame(width: 10, height: 10)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("PICKUP").font(EFont.body(9, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.5)
                            Text(vm.currentTrip?.pickupAddress ?? vm.pickupAddress).font(EFont.body(13)).foregroundColor(.eText).lineLimit(2)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("DROP-OFF").font(EFont.body(9, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.5)
                            Text(vm.currentTrip?.dropoffAddress ?? vm.dropoffAddress).font(EFont.body(13)).foregroundColor(.eText).lineLimit(2)
                        }
                    }
                    Spacer()
                }
                .padding(14)

                if let km = vm.currentTrip?.estimatedDistanceKm {
                    Divider().background(Color.eBorder)
                    HStack(spacing: 16) {
                        Label(String(format: "%.1f km", km), systemImage: "arrow.triangle.swap")
                            .font(EFont.body(12)).foregroundColor(.eTextMuted)
                        if let dur = vm.currentTrip?.estimatedDurationMin {
                            Label(String(format: "%.0f min total", dur), systemImage: "clock")
                                .font(EFont.body(12)).foregroundColor(.eTextMuted)
                        }
                        Spacer()
                        Text(vm.currentTrip?.rideType.capitalized ?? "").font(EFont.body(11, weight: .semibold)).foregroundColor(.eTextMuted)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
            }
            .background(Color.eSurface)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.eBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 13)).padding(.bottom, 12)
            HStack(spacing:10){
                PInRideActionBtn(icon:"phone.fill",label:"Call",tint:.eGreen)
                PInRideActionBtn(icon:"message.fill",label:"Chat",tint:Color(hex:"#4488FF"))
                PInRideActionBtn(icon:"shield.fill",label:"SOS",tint:.eRed)
            }
        }
        .padding(.horizontal,20).padding(.bottom,40).background(Color.eCard).clipShape(RoundedRectangle(cornerRadius:28,style:.continuous))
        .overlay(alignment:.top){RoundedRectangle(cornerRadius:28,style:.continuous).stroke(Color.eBorder,lineWidth:1)}
        .alert("Cancel Ride?",isPresented:$showCancel){Button("Cancel Ride",role:.destructive){vm.cancelRide()};Button("Keep Ride",role:.cancel){}}
        message:{Text("A cancellation fee may apply.")}
    }
}
struct PInRideActionBtn: View {
    let icon: String; let label: String; let tint: Color
    var body: some View {
        Button{} label: { HStack(spacing:6){Image(systemName:icon).font(.system(size:13));Text(label).font(EFont.body(13,weight:.semibold))}.foregroundColor(tint).frame(maxWidth:.infinity).padding(.vertical,13).background(Color.eSurface).overlay(RoundedRectangle(cornerRadius:13).stroke(Color.eBorder,lineWidth:1)).clipShape(RoundedRectangle(cornerRadius:13)) }
    }
}

// MARK: - Payment / Rating (ZipRide PaymentView)
struct PPaymentView: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var amountVisible = false
    private let tags = ["Great driver","Clean car","On time","Safe driving","Friendly","Smooth ride"]
    var body: some View {
        ZStack { Color.eBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Trip Complete").font(EFont.display(20,weight:.heavy)).foregroundColor(.eText).padding(.top,54).padding(.bottom,16).frame(maxWidth:.infinity,alignment:.leading)
                    ZStack {
                        LinearGradient(colors:[Color.eCard,Color(hex:"#0E1520")],startPoint:.init(x:0.2,y:0),endPoint:.init(x:0.8,y:1))
                        RadialGradient(colors:[Color.eGreen.opacity(0.08),.clear],center:.top,startRadius:0,endRadius:160)
                        VStack(spacing: 0) {
                            ZStack{Circle().fill(Color.eGreen.opacity(0.1)).frame(width:64,height:64);Circle().stroke(Color.eGreen.opacity(0.3),lineWidth:2).frame(width:64,height:64);Image(systemName:"checkmark").font(.system(size:26,weight:.bold)).foregroundColor(.eGreen)}.padding(.bottom,14).scaleEffect(amountVisible ? 1:0.5).opacity(amountVisible ? 1:0)
                            Text("Total Paid").font(EFont.body(13)).foregroundColor(.eTextSoft).padding(.bottom,6)
                            HStack(alignment:.firstTextBaseline,spacing:2){Text("R").font(EFont.display(22,weight:.bold)).foregroundColor(.eGreen).baselineOffset(12);Text("\(Int(vm.currentTrip?.totalFare ?? 0))").font(EFont.display(46,weight:.heavy)).foregroundColor(.eText).kerning(-2)}.opacity(amountVisible ? 1:0).offset(y:amountVisible ? 0:20)
                        }.padding(.vertical,28)
                    }.clipShape(RoundedRectangle(cornerRadius:24,style:.continuous)).overlay(RoundedRectangle(cornerRadius:24,style:.continuous).stroke(Color.eBorder,lineWidth:1)).padding(.bottom,16)
                    // Rating card
                    VStack(spacing: 0) {
                        Text("How was your ride?").font(EFont.body(13)).foregroundColor(.eTextSoft).padding(.bottom,14)
                        HStack(spacing:10){ForEach(1...5,id:\.self){i in Button{withAnimation(.spring(response:0.3)){vm.selectedRating=i}}label:{Image(systemName:i<=vm.selectedRating ? "star.fill":"star").font(.system(size:32)).foregroundColor(i<=vm.selectedRating ? .eAccent:.eBorder).scaleEffect(i==vm.selectedRating ? 1.15:1)}}}.padding(.bottom,16)
                        VStack(alignment:.leading,spacing:8){
                            HStack(spacing:8){ForEach(tags.prefix(3),id:\.self){tag in ratingChip(tag)}}
                            HStack(spacing:8){ForEach(Array(tags.dropFirst(3)),id:\.self){tag in ratingChip(tag)}}
                        }.frame(maxWidth:.infinity,alignment:.center)
                    }.padding(18).background(Color.eCard).overlay(RoundedRectangle(cornerRadius:16).stroke(Color.eBorder,lineWidth:1)).clipShape(RoundedRectangle(cornerRadius:16)).padding(.bottom,24)
                    EPrimaryButton(title:"Submit Rating"){vm.submitRating()}
                    Button{vm.goHome()}label:{Text("Skip").font(EFont.body(14)).foregroundColor(.eTextMuted).frame(maxWidth:.infinity).padding(.vertical,14)}
                }.padding(.horizontal,20).padding(.bottom,48)
            }
        }.onAppear{withAnimation(.spring(response:0.8).delay(0.3)){amountVisible=true}}
    }
    @ViewBuilder private func ratingChip(_ tag: String) -> some View {
        let sel = vm.ratingTags.contains(tag)
        Button{if sel{vm.ratingTags.remove(tag)}else{vm.ratingTags.insert(tag)}}label:{Text(tag).font(EFont.body(12,weight:.semibold)).foregroundColor(sel ? .eGreen:.eTextSoft).padding(.horizontal,12).padding(.vertical,6).background(sel ? Color.eGreen.opacity(0.1):Color.eSurface).overlay(Capsule().stroke(sel ? Color.eGreen.opacity(0.3):Color.eBorder,lineWidth:1)).clipShape(Capsule())}
    }
}

// MARK: - History (ZipRide HistoryView)
struct PHistoryView: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var filter: String? = nil
    var filtered: [BETrip] { guard let f=filter else{return vm.tripHistory}; return vm.tripHistory.filter{ f=="cancelled" ? $0.status.contains("cancelled")||$0.status=="no_driver_found" : $0.status==f } }
    var body: some View {
        ZStack{Color.eBackground.ignoresSafeArea()
            ScrollView(showsIndicators:false){VStack(alignment:.leading,spacing:0){
                Text("My Trips").font(EFont.display(26,weight:.heavy)).foregroundColor(.eText).kerning(-0.5).padding(.top,54).padding(.bottom,16)
                HStack(spacing:8){PFilterTab(label:"All",isActive:filter==nil){withAnimation{filter=nil}};PFilterTab(label:"Completed",isActive:filter=="completed"){withAnimation{filter="completed"}};PFilterTab(label:"Cancelled",isActive:filter=="cancelled"){withAnimation{filter="cancelled"}}}.padding(.bottom,20)
                if filtered.isEmpty { VStack(spacing:16){Image(systemName:"clock.badge.xmark").font(.system(size:48)).foregroundColor(.eGreen.opacity(0.4));Text("No trips yet").font(EFont.display(18,weight:.bold)).foregroundColor(.eText);Text("Your trip history will appear here").font(EFont.body(14)).foregroundColor(.eTextMuted)}.frame(maxWidth:.infinity).padding(.vertical,60) }
                else { VStack(spacing:10){ForEach(filtered){PTripCard(trip:$0)}}.padding(.bottom,8) }
                Spacer(minLength:100)
            }.padding(.horizontal,20)}
        }.task{await vm.loadHistory()}
    }
}
struct PFilterTab: View {
    let label:String;let isActive:Bool;let action:()->Void
    var body: some View{Button(action:action){Text(label).font(EFont.body(13,weight:isActive ? .bold:.semibold)).foregroundColor(isActive ? .black:.eTextSoft).padding(.horizontal,16).padding(.vertical,8).background(isActive ? Color.eGreen:Color.clear).overlay(Capsule().stroke(isActive ? Color.clear:Color.eBorder,lineWidth:1.5)).clipShape(Capsule())}}
}
struct PTripCard: View {
    let trip: BETrip
    var body: some View {
        VStack(spacing:0){
            HStack(alignment:.top){VStack(alignment:.leading,spacing:3){Text(trip.rideType.capitalized).font(EFont.display(15,weight:.bold)).foregroundColor(.eText);Text(trip.statusLabel).font(EFont.body(12)).foregroundColor(.eTextMuted)};Spacer()
                VStack(alignment:.trailing,spacing:2){if trip.status=="completed"{Text(trip.fareStr).font(EFont.display(18,weight:.heavy)).foregroundColor(.eText);Text("Completed").font(EFont.body(11)).foregroundColor(.eTextMuted)}else{Text("Cancelled").font(EFont.display(15,weight:.bold)).foregroundColor(.eRed)}}
            }.padding(.bottom,14)
            VStack(alignment:.leading,spacing:0){
                HStack(spacing:10){Image(systemName:"circle.fill").font(.system(size:9)).foregroundColor(.eGreen).frame(width:14);Text(trip.pickupAddress).font(EFont.body(12)).foregroundColor(.eTextSoft)}
                Rectangle().fill(Color.eBorder).frame(width:1,height:14).padding(.leading,6)
                HStack(spacing:10){Image(systemName:"square.fill").font(.system(size:9)).foregroundColor(trip.status=="completed" ? .eAccent:.eTextMuted).frame(width:14);Text(trip.dropoffAddress).font(EFont.body(12)).foregroundColor(.eTextSoft)}
            }
            if trip.status=="completed"{HStack(spacing:8){HStack(spacing:2){ForEach(1...5,id:\.self){i in Image(systemName:"star.fill").font(.system(size:11)).foregroundColor(.eAccent)}};if let km=trip.estimatedDistanceKm{Text(String(format:"%.1f km",km)).font(EFont.body(12)).foregroundColor(.eTextMuted)}}.padding(.top,12).overlay(alignment:.top){Rectangle().fill(Color.eBorder).frame(height:1).offset(y:-1)}}
        }.padding(16).background(Color.eCard).overlay(RoundedRectangle(cornerRadius:16).stroke(Color.eBorder,lineWidth:1)).clipShape(RoundedRectangle(cornerRadius:16)).opacity(trip.status.contains("cancelled") ? 0.7:1)
    }
}

// MARK: - Profile (ZipRide ProfileView)
struct PProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var vm: PassengerViewModel
    @State private var showSignOut = false
    var body: some View {
        ZStack{Color.eBackground.ignoresSafeArea()
            ScrollView(showsIndicators:false){VStack(spacing:0){
                ZStack(alignment:.bottom){
                    LinearGradient(colors:[Color(hex:"#0A1F14"),Color(hex:"#0A1018")],startPoint:.topLeading,endPoint:.bottomTrailing).frame(height:260)
                    HStack{Text("Profile").font(EFont.display(20,weight:.heavy)).foregroundColor(.eText);Spacer();ZStack{Image(systemName:"bell.fill").font(.system(size:18)).foregroundColor(.eText).frame(width:40,height:40).background(Color.eSurface).clipShape(Circle());Circle().fill(Color.eRed).frame(width:8,height:8).offset(x:12,y:-12)}}.padding(.horizontal,20).frame(maxHeight:.infinity,alignment:.top).padding(.top,54)
                    VStack(spacing:10){ZStack{Circle().fill(LinearGradient(colors:[Color(hex:"#1C2535"),Color(hex:"#252B38")],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:90,height:90).overlay(Circle().stroke(Color.eGreen,lineWidth:3));Text(vm.user.initials).font(EFont.display(32,weight:.heavy)).foregroundColor(.eGreen)}.shadow(color:Color.eGreen.opacity(0.25),radius:20)
                        Text(vm.user.fullName).font(EFont.display(20,weight:.heavy)).foregroundColor(.eText);Text(vm.user.phone).font(EFont.body(13)).foregroundColor(.eTextSoft)
                        HStack(spacing:5){Image(systemName:"star.fill").font(.system(size:11)).foregroundColor(.eGreen);Text("5.00").font(EFont.body(13,weight:.bold)).foregroundColor(.eGreen);Text("· \(vm.tripHistory.count) trips").font(EFont.body(12)).foregroundColor(.eTextMuted)}.padding(.horizontal,14).padding(.vertical,6).background(Color.eGreen.opacity(0.08)).overlay(Capsule().stroke(Color.eGreen.opacity(0.2),lineWidth:1)).clipShape(Capsule())
                    }.padding(.bottom,20)
                }
                HStack(spacing:0){PStatCell(val:"\(vm.tripHistory.count)",label:"Trips",color:.eGreen);Rectangle().fill(Color.eBorder).frame(width:1,height:50);PStatCell(val:"R\(Int(vm.tripHistory.compactMap{$0.totalFare}.reduce(0,+)))",label:"Spent",color:.eAccent);Rectangle().fill(Color.eBorder).frame(width:1,height:50);PStatCell(val:"5.0",label:"Rating",color:Color(hex:"#4488FF"))}.background(Color.eCard).overlay(alignment:.bottom){Rectangle().fill(Color.eBorder).frame(height:1)}
                PPSection("ACCOUNT")
                PPRow(icon:"person.fill",bg:.init(hex:"#4488FF"),title:"Personal Information",sub:vm.user.email ?? "Tap to edit"){}
                PPRow(icon:"bell.fill",bg:.eAccent,title:"Notifications",sub:"Manage alerts"){}
                PPRow(icon:"creditcard.fill",bg:.eGreen,title:"Payment Methods",sub:"Cash"){}
                PPRow(icon:"gift.fill",bg:.init(hex:"#9B59FF"),title:"Promo Codes",sub:"Redeem discount codes",badge:"NEW"){}
                PPSection("SAFETY")
                PPRow(icon:"shield.fill",bg:.eRed,title:"Safety Settings",sub:"Emergency contacts, panic button"){}
                PPSection("PREFERENCES")
                PPRow(icon:"questionmark.circle.fill",bg:.init(hex:"#444"),title:"Help & Support",sub:"FAQs, contact us"){}
                PPRow(icon:"doc.text.fill",bg:.init(hex:"#333"),title:"Terms & Privacy",sub:"Read our policies"){}
                Button{showSignOut=true}label:{HStack(spacing:12){ZStack{RoundedRectangle(cornerRadius:8).fill(Color.eRed.opacity(0.12)).frame(width:34,height:34);Image(systemName:"rectangle.portrait.and.arrow.right").font(.system(size:14)).foregroundColor(.eRed)};Text("Sign Out").font(EFont.body(14,weight:.semibold)).foregroundColor(.eRed);Spacer()}.padding(.horizontal,20).padding(.vertical,14).background(Color.eCard)}.padding(.top,8)
                Text("eTaxi v1.0 · ZA Edition").font(EFont.body(11)).foregroundColor(.eTextMuted).frame(maxWidth:.infinity).padding(.vertical,20)
                Spacer(minLength:100)
            }}
        }
        .alert("Sign Out",isPresented:$showSignOut){Button("Sign Out",role:.destructive){authVM.logout()};Button("Cancel",role:.cancel){}}message:{Text("Are you sure you want to sign out?")}
    }
}
struct PStatCell: View {
    let val:String;let label:String;let color:Color
    var body: some View{VStack(spacing:4){Text(val).font(EFont.display(18,weight:.heavy)).foregroundColor(color);Text(label).font(EFont.body(11)).foregroundColor(.eTextMuted)}.frame(maxWidth:.infinity).padding(.vertical,18)}
}
struct PPSection: View {
    let t:String; init(_ t:String){self.t=t}
    var body: some View{Text(t).font(EFont.body(11,weight:.bold)).foregroundColor(.eTextMuted).kerning(0.8).frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,20).padding(.top,22).padding(.bottom,6)}
}
struct PPRow: View {
    let icon:String;let bg:Color;let title:String;let sub:String;var badge:String?=nil;let action:()->Void
    var body: some View{Button(action:action){HStack(spacing:14){ZStack{RoundedRectangle(cornerRadius:8).fill(bg.opacity(0.18)).frame(width:36,height:36);Image(systemName:icon).font(.system(size:15)).foregroundColor(bg)};VStack(alignment:.leading,spacing:2){HStack(spacing:6){Text(title).font(EFont.body(14,weight:.semibold)).foregroundColor(.eText);if let b=badge{Text(b).font(EFont.body(9,weight:.bold)).foregroundColor(.eGreen).padding(.horizontal,5).padding(.vertical,2).background(Color.eGreen.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius:4))}};Text(sub).font(EFont.body(12)).foregroundColor(.eTextMuted).lineLimit(1)};Spacer();Image(systemName:"chevron.right").font(.system(size:12,weight:.semibold)).foregroundColor(.eTextMuted.opacity(0.5))}.padding(.horizontal,20).padding(.vertical,13).background(Color.eCard)}.overlay(alignment:.bottom){Rectangle().fill(Color.eBorder.opacity(0.5)).frame(height:0.5).padding(.leading,70)}}
}


// MARK: - Wallet (ZipRide WalletView)
struct PWalletView: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var method = "cash"
    var body: some View {
        ZStack{Color.eBackground.ignoresSafeArea()
            ScrollView(showsIndicators:false){VStack(alignment:.leading,spacing:0){
                Text("Wallet").font(EFont.display(26,weight:.heavy)).foregroundColor(.eText).kerning(-0.5).padding(.top,54).padding(.bottom,4)
                Text("Choose your default payment method").font(EFont.body(13)).foregroundColor(.eTextMuted).padding(.bottom,28)
                Text("PAYMENT METHOD").font(EFont.body(11,weight:.bold)).foregroundColor(.eTextMuted).kerning(0.8).padding(.bottom,12)
                HStack(spacing:0){pwBtn("card","creditcard.fill","Card");pwBtn("cash","banknote.fill","Cash")}.padding(4).background(Color.eCard).overlay(RoundedRectangle(cornerRadius:13).stroke(Color.eBorder,lineWidth:1)).clipShape(RoundedRectangle(cornerRadius:13)).padding(.bottom,20)
                if method=="cash" { pwInfo("banknote.fill",.eAccent,"Cash Payment","Pay your driver directly in cash at the end of the trip.",["No card required","Pay driver directly","Exact fare shown before you confirm"]) }
                else { pwInfo("creditcard.fill",.eGreen,"Card Payment","Pay securely by card. Full card management coming soon.",["Secure online payment","No cash needed","Instant payment on trip completion"]) }
                Spacer(minLength:120)
            }.padding(.horizontal,20)}
        }
    }
    @ViewBuilder private func pwBtn(_ m:String,_ icon:String,_ label:String)->some View{
        let sel=method==m
        Button{withAnimation(.spring(response:0.3)){method=m}}label:{HStack(spacing:8){Image(systemName:icon).font(.system(size:14));Text(label).font(EFont.body(14,weight:.bold))}.foregroundColor(sel ? .black:.eTextMuted).frame(maxWidth:.infinity).padding(.vertical,14).background(sel ? Color.eGreen:Color.clear).clipShape(RoundedRectangle(cornerRadius:11))}
    }
    @ViewBuilder private func pwInfo(_ icon:String,_ color:Color,_ title:String,_ desc:String,_ pts:[String])->some View{
        VStack(alignment:.leading,spacing:14){HStack(spacing:14){ZStack{RoundedRectangle(cornerRadius:12).fill(color.opacity(0.15)).frame(width:52,height:52);Image(systemName:icon).font(.system(size:22)).foregroundColor(color)};VStack(alignment:.leading,spacing:4){Text(title).font(EFont.body(15,weight:.bold)).foregroundColor(.eText);Text(desc).font(EFont.body(13)).foregroundColor(.eTextMuted)}};Rectangle().fill(Color.eBorder).frame(height:1);VStack(alignment:.leading,spacing:10){ForEach(pts,id:\.self){pt in HStack(spacing:8){Image(systemName:"checkmark.circle.fill").font(.system(size:13)).foregroundColor(.eGreen);Text(pt).font(EFont.body(13)).foregroundColor(.eTextSoft)}}}}.padding(18).background(Color.eCard).overlay(RoundedRectangle(cornerRadius:16).stroke(Color.eBorder,lineWidth:1)).clipShape(RoundedRectangle(cornerRadius:16))
    }
}

// MARK: - Service Choice
struct PServiceChoiceView: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var appeared = false
    var body: some View {
        ZStack{Color.eBackground.ignoresSafeArea()
            VStack(spacing:0){Spacer()
                ZStack{RoundedRectangle(cornerRadius:20).fill(Color.eGreen).frame(width:72,height:72).shadow(color:Color.eGreen.opacity(0.4),radius:20,y:6);Text("eT").font(.system(size:26,weight:.black,design:.rounded)).foregroundColor(.black)}.scaleEffect(appeared ? 1:0.7).opacity(appeared ? 1:0).padding(.bottom,24)
                Text("How do you want\nto get around?").font(EFont.display(30,weight:.heavy)).foregroundColor(.eText).multilineTextAlignment(.center).opacity(appeared ? 1:0).padding(.bottom,8)
                Text("Choose your default service. You can always switch later.").font(EFont.body(15)).foregroundColor(.eTextSoft).multilineTextAlignment(.center).padding(.horizontal,32).opacity(appeared ? 1:0).padding(.bottom,40)
                psCard("⚡️",Color.eGreen.opacity(0.18),"Standard Ride","POPULAR",.eGreen,"On-demand metered trips",["Pay per km + time","Driver arrives in minutes","Economy · Comfort · XL · Ladies"],Color.eGreen.opacity(0.3)){vm.selectPreference("standard")}.padding(.bottom,16)
                psCard("📅",Color(hex:"#3D2B8F").opacity(0.4),"Custom Hire","FLAT RATE",Color(hex:"#7B6FD8"),"Flat-rate hourly & daily packages",["Fixed price — no surprises","Hourly · Half day · Full day","Perfect for events & long trips"],Color(hex:"#3D2B8F").opacity(0.5)){vm.selectPreference("custom")}.padding(.bottom,32)
                Button{vm.selectPreference("standard")}label:{Text("Skip — use Standard for now").font(EFont.body(14)).foregroundColor(.eTextMuted)}
                Spacer()
            }.padding(.horizontal,20)
        }.onAppear{withAnimation(.spring(response:0.6,dampingFraction:0.8).delay(0.1)){appeared=true}}
    }
    @ViewBuilder private func psCard(_ emoji:String,_ emojiBg:Color,_ title:String,_ badge:String,_ badgeColor:Color,_ desc:String,_ bullets:[String],_ border:Color,_ action:@escaping()->Void)->some View{
        Button(action:action){HStack(alignment:.top,spacing:16){ZStack{RoundedRectangle(cornerRadius:14).fill(emojiBg).frame(width:52,height:52);Text(emoji).font(.system(size:26))};VStack(alignment:.leading,spacing:6){HStack(spacing:8){Text(title).font(EFont.body(17,weight:.bold)).foregroundColor(.eText);Text(badge).font(EFont.body(10,weight:.bold)).foregroundColor(badgeColor).padding(.horizontal,8).padding(.vertical,3).background(badgeColor.opacity(0.15)).clipShape(Capsule())};Text(desc).font(EFont.body(13)).foregroundColor(.eTextSoft);ForEach(bullets,id:\.self){b in HStack(spacing:8){Circle().fill(badgeColor).frame(width:5,height:5);Text(b).font(EFont.body(12)).foregroundColor(.eTextSoft)}}};Spacer();Image(systemName:"arrow.right").font(.system(size:14,weight:.bold)).foregroundColor(.eText).frame(width:32,height:32).background(badgeColor).clipShape(Circle())}.padding(18).background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius:20)).overlay(RoundedRectangle(cornerRadius:20).stroke(border,lineWidth:1.5))}
    }
}

// MARK: - Custom Hire + Hire Confirmed
struct PCustomHireView: View {
    @ObservedObject var vm: PassengerViewModel
    @State private var mapRegion = MKCoordinateRegion(center:.init(latitude:-26.1076,longitude:28.0567),span:.init(latitudeDelta:0.02,longitudeDelta:0.02))
    @State private var showDatePicker=false
    let dur=[(String,String,String)](arrayLiteral:("⏰","Hourly","hourly"),("🌤","Half Day","halfday"),("☀️","Full Day","fullday"),("🏖","Weekend","weekend"))
    var body: some View {
        ZStack{Map(coordinateRegion:$mapRegion,showsUserLocation:true).ignoresSafeArea()
            VStack{HStack{Button{vm.screen = .home}label:{Image(systemName:"arrow.left").font(.system(size:16,weight:.semibold)).foregroundColor(.eText).frame(width:42,height:42).background(Color.eSurface.opacity(0.95)).clipShape(RoundedRectangle(cornerRadius:12))};VStack(alignment:.leading,spacing:2){Text("Custom Hire").font(EFont.display(18,weight:.heavy)).foregroundColor(.eText);Text("Flat-rate packages").font(EFont.body(12)).foregroundColor(.eTextSoft)}.padding(.leading,8);Spacer()}.padding(.horizontal,16).padding(.top,52);Spacer()}
            VStack{Spacer()
                VStack(spacing:0){ESheetHandle().padding(.top,12).padding(.bottom,16)
                    ScrollView(showsIndicators:false){VStack(spacing:16){
                        VStack(alignment:.leading,spacing:12){Label("Start Date & Time",systemImage:"calendar").font(EFont.body(14,weight:.semibold)).foregroundColor(.eTextSoft);HStack(spacing:12){Button{showDatePicker.toggle()}label:{Text(vm.hireDate.formatted(.dateTime.day().month(.abbreviated).year())).font(EFont.body(16,weight:.bold)).foregroundColor(.eText).padding(.horizontal,16).padding(.vertical,12).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius:12))};Button{showDatePicker.toggle()}label:{Text(vm.hireDate.formatted(.dateTime.hour().minute())).font(EFont.body(16,weight:.bold)).foregroundColor(.eText).padding(.horizontal,16).padding(.vertical,12).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius:12))}};if showDatePicker{DatePicker("",selection:$vm.hireDate,in:Date()...).datePickerStyle(.graphical).tint(.eGreen)}}.padding(16).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius:16))
                        VStack(alignment:.leading,spacing:12){Label("Duration",systemImage:"clock").font(EFont.body(14,weight:.semibold)).foregroundColor(.eTextSoft);HStack(spacing:10){ForEach(dur,id:\.1){e,l,k in let sel=vm.hireDuration==k;Button{withAnimation(.spring(response:0.3)){vm.hireDuration=k}}label:{VStack(spacing:6){Text(e).font(.system(size:24));Text(l).font(EFont.body(12,weight:sel ? .bold:.regular)).foregroundColor(sel ? .black:.eText)}.frame(maxWidth:.infinity).frame(height:72).background(sel ? Color(hex:"#6366F1"):Color.eSurface).clipShape(RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(sel ? Color.clear:Color.eBorder,lineWidth:1))}}}.padding(16).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius:16))
                        if let err=vm.errorMessage{EErrorBanner(message:err)};Spacer(minLength:80)
                    }.padding(.horizontal,20)}
                }.background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius:28,style:.continuous)).frame(maxHeight:UIScreen.main.bounds.height*0.65)
                Button{vm.confirmHire()}label:{Text(vm.hireEstimatedFare>0 ? "Confirm Hire · R\(Int(vm.hireEstimatedFare))":"Confirm Hire").font(EFont.body(16,weight:.bold)).foregroundColor(.black).frame(maxWidth:.infinity).frame(height:56).background(vm.isLoading ? Color.eSurface:Color(hex:"#6366F1")).clipShape(RoundedRectangle(cornerRadius:16))}.disabled(vm.isLoading).padding(.horizontal,20).padding(.vertical,12).background(Color.eSurface)
            }
            }
        }.ignoresSafeArea().onAppear{if let c=LocationManager.shared.coordinate{mapRegion.center=c}}
    }
}
struct PHireConfirmedView: View {
    @ObservedObject var vm: PassengerViewModel
    var body: some View {
        ZStack{Color.eBackground.ignoresSafeArea();VStack(spacing:24){Spacer();HStack(spacing:10){Circle().fill(Color(hex:"#6366F1")).frame(width:10,height:10);Text("Hire Confirmed").font(EFont.body(16,weight:.bold)).foregroundColor(.eText)}.padding(.horizontal,20).padding(.vertical,12).background(Color(hex:"#1E1B3A")).clipShape(Capsule());Text(vm.hireDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())).font(.system(size:28,weight:.black,design:.rounded)).foregroundColor(.eText).multilineTextAlignment(.center);Text(vm.pickupAddress).font(EFont.body(14)).foregroundColor(.eTextSoft).multilineTextAlignment(.center).padding(.horizontal,40);Text("R\(Int(vm.currentTrip?.totalFare ?? vm.hireEstimatedFare))").font(.system(size:52,weight:.black,design:.rounded)).foregroundColor(.eAccent);EPrimaryButton(title:"Done"){vm.goHome()}.padding(.horizontal,20);Spacer()}}
    }
}

// EPrimaryButton defined in Core/Utils/DesignSystem.swift

// Design tokens defined in DesignSystem.swift
