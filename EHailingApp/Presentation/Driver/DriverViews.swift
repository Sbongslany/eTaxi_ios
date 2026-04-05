import SwiftUI
import MapKit

// MARK: - Driver Root
struct DriverRoot: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm: DriverViewModel
    init(user: UserEntity) { _vm = StateObject(wrappedValue: DriverViewModel(user: user)) }
    @ViewBuilder var body: some View {
        switch vm.screen {
        case .home:        DMainTabView(vm: vm)
        case .enRoute:     DEnRouteView(vm: vm)
        case .arrived:     DArrivedView(vm: vm)
        case .activeTrip:  DActiveTripView(vm: vm)
        case .tripComplete: DTripCompleteView(vm: vm)
        default:           DMainTabView(vm: vm)
        }
    }
}

// MARK: - Driver Main Tab View (matching ZipRide DriverMainTabView)
struct DMainTabView: View {
    @ObservedObject var vm: DriverViewModel
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch vm.selectedTab {
                case 0:  DHomeView(vm: vm)
                case 1:  DTripsView(vm: vm)
                case 2:  DEarningsView(vm: vm)
                default: DProfileView(vm: vm)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if vm.hasPending, let req = vm.pendingRequest {
                DTripRequestOverlay(vm: vm, request: req)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                    .animation(.spring(response: 0.4), value: vm.hasPending)
            }

            DDriverTabBar(vm: vm)
        }
        .background(Color.eBackground.ignoresSafeArea())
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Driver Tab Bar (matching ZipRide DriverTabBar with per-tab colors)
struct DDriverTabBar: View {
    @ObservedObject var vm: DriverViewModel
    @State private var bounceTab: Int? = nil
    private let tabs = [
        ("map", "map.fill", "Map"),
        ("list.bullet.rectangle", "list.bullet.rectangle.fill", "Trips"),
        ("chart.bar", "chart.bar.fill", "Earnings"),
        ("person", "person.fill", "Profile")
    ]
    private func accent(_ i: Int) -> Color {
        switch i { case 0: return .eGreen; case 1: return Color(hex:"#4488FF"); case 2: return .eAccent; default: return Color(hex:"#9B59FF") }
    }
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                let (icon, filled, label) = tabs[i]; let sel = vm.selectedTab == i
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { bounceTab = i; vm.selectedTab = i }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { bounceTab = nil }
                    if i == 2 { Task { await vm.loadEarnings() } }
                    if i == 1 { Task { await vm.loadHistory() } }
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            if sel { RoundedRectangle(cornerRadius: 12).fill(accent(i).opacity(0.15)).frame(width: 48, height: 32) }
                            Image(systemName: sel ? filled : icon)
                                .font(.system(size: 20, weight: sel ? .bold : .regular))
                                .foregroundColor(sel ? accent(i) : .eTextMuted)
                                .frame(width: 48, height: 32)
                                .scaleEffect(bounceTab == i ? 1.2 : 1.0)
                        }
                        Text(label).font(.system(size: 10, weight: sel ? .bold : .medium)).foregroundColor(sel ? accent(i) : .eTextMuted)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 10).padding(.bottom, 4).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .padding(.bottom, 24)
        .background(
            ZStack { Color.eCard; Rectangle().fill(.ultraThinMaterial).opacity(0.3) }
                .overlay(alignment: .top) { LinearGradient(colors: [Color.eBorder, .clear], startPoint: .leading, endPoint: .trailing).frame(height: 0.5) }
                .ignoresSafeArea(edges: .bottom)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: -4)
    }
}

// MARK: - Driver Home View (matching ZipRide DriverHomeView)
struct DHomeView: View {
    @ObservedObject var vm: DriverViewModel
    @StateObject private var locMgr = LocationManager.shared
    @State private var region = MKCoordinateRegion(center: .init(latitude: -26.1076, longitude: 28.0567), span: .init(latitudeDelta: 0.04, longitudeDelta: 0.04))
    @State private var hasInitiallyCentred = false
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: $region, showsUserLocation: true).ignoresSafeArea()
            VStack { DTopBar(vm: vm); Spacer() }.ignoresSafeArea(edges: .top)
            if vm.isOnline {
                DOnlineStatsStrip(vm: vm).transition(.move(edge: .bottom).combined(with: .opacity))
            }
            DStatusSheet(vm: vm)
        }
        .animation(.spring(response: 0.4), value: vm.isOnline)
        .onAppear { locMgr.start() }
        .onChange(of: locMgr.coordinate) { coord in
            guard let coord else { return }
            if !hasInitiallyCentred || locMgr.accuracy < 50 {
                withAnimation(.easeInOut(duration: 1.2)) { region.center = coord; region.span = .init(latitudeDelta: 0.012, longitudeDelta: 0.012) }
                hasInitiallyCentred = true
            }
        }
        .task { await vm.loadProfile() }
    }
}

// MARK: - Driver Top Bar (matching ZipRide DriverTopBar)
struct DTopBar: View {
    @ObservedObject var vm: DriverViewModel
    var body: some View {
        VStack(spacing: 0) {
            Color.eBackground.opacity(0.88).frame(height: 0)
            HStack {
                HStack(spacing: 4) {
                    ZStack { RoundedRectangle(cornerRadius: 7).fill(Color.eGreen).frame(width: 26, height: 26); Text("eT").font(EFont.display(11, weight: .heavy)).foregroundColor(.black) }
                    HStack(spacing: 0) { Text("e").font(EFont.display(18, weight: .heavy)).foregroundColor(.eText); Text("Taxi").font(EFont.display(18, weight: .heavy)).foregroundColor(.eGreen) }
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(vm.isOnline ? Color.eGreen : Color.eTextMuted).frame(width: 8, height: 8)
                    Text(vm.isOnline ? "Online" : "Offline").font(EFont.body(12, weight: .bold)).foregroundColor(vm.isOnline ? .eGreen : .eTextMuted)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background((vm.isOnline ? Color.eGreen : Color.eTextMuted).opacity(0.12))
                .overlay(Capsule().stroke((vm.isOnline ? Color.eGreen : Color.eTextMuted).opacity(0.3), lineWidth: 1)).clipShape(Capsule())
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(LinearGradient(colors: [Color.eBackground.opacity(0.85), Color.eBackground.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .top))
        .padding(.top, 44)
    }
}

// MARK: - Online Stats Strip (matching ZipRide DriverOnlineStatsStrip)
struct DOnlineStatsStrip: View {
    @ObservedObject var vm: DriverViewModel
    var body: some View {
        HStack(spacing: 0) {
            DStatCell(value: "R\(Int(vm.earnings?.todayNum ?? 0))", label: "Today")
            Divider().background(Color.eBorder).frame(height: 30)
            DStatCell(value: "\(vm.tripHistory.count)", label: "Trips")
            Divider().background(Color.eBorder).frame(height: 30)
            DStatCell(value: "—h", label: "Online")
            Divider().background(Color.eBorder).frame(height: 30)
            DStatCell(value: "100%", label: "Acceptance")
        }
        .padding(.vertical, 12).background(Color.eCard.opacity(0.94))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.eBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .padding(.horizontal, 20).padding(.bottom, 140)
    }
}
struct DStatCell: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(EFont.display(16, weight: .heavy)).foregroundColor(.eText)
            Text(label).font(EFont.body(10, weight: .semibold)).foregroundColor(.eTextMuted)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - Status Sheet (matching ZipRide DriverStatusSheet exactly)
struct DStatusSheet: View {
    @ObservedObject var vm: DriverViewModel
    var isVerified: Bool { vm.profile?.isVerified ?? true } // dev: always verified

    var body: some View {
        VStack(spacing: 0) {
            ESheetHandle().padding(.top, 12).padding(.bottom, 18)

            if vm.isOnline {
                // Online state
                VStack(spacing: 6) {
                    HStack(spacing: 8) { DPulsingDot(color: .eGreen); Text("You're Online").font(EFont.display(18, weight: .bold)).foregroundColor(.eText) }
                    Text("Stay in a busy area for faster requests").font(EFont.body(13)).foregroundColor(.eTextSoft)
                }.padding(.bottom, 20)
                Button { vm.goOffline() } label: {
                    Text("Go Offline").font(EFont.body(15, weight: .semibold)).foregroundColor(.eTextMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.eBorder, lineWidth: 1.5))
                }.padding(.horizontal, 24)
            } else {
                // Offline + verified
                VStack(spacing: 6) {
                    ZStack { Circle().fill(Color.eGreen.opacity(0.1)).frame(width: 56, height: 56); Image(systemName: "checkmark.seal.fill").font(.system(size: 24)).foregroundColor(.eGreen) }
                    Text("You're Offline").font(EFont.display(22, weight: .heavy)).foregroundColor(.eText)
                    Text("Tap below to start accepting trips").font(EFont.body(14)).foregroundColor(.eTextSoft)
                }.padding(.bottom, 24)

                if let err = vm.errorMessage {
                    Text(err).font(EFont.body(12)).foregroundColor(.eRed).multilineTextAlignment(.center)
                        .padding(.horizontal, 24).padding(.bottom, 12)
                }

                Button { vm.goOnline() } label: {
                    HStack(spacing: 10) {
                        Circle().fill(Color.black.opacity(0.2)).frame(width: 10, height: 10)
                        if vm.isLoading { ProgressView().tint(.black) }
                        else { Text("Go Online").font(EFont.body(17, weight: .bold)).foregroundColor(.black) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 18).background(Color.eGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.eGreen.opacity(0.4), radius: 12, y: 4)
                }.padding(.horizontal, 24).disabled(vm.isLoading)
            }
        }
        .padding(.bottom, 96).background(Color.eCard)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.eBorder, lineWidth: 1) }
    }
}

struct DPulsingDot: View {
    let color: Color; @State private var pulse = false
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.3)).frame(width: pulse ? 18 : 10, height: pulse ? 18 : 10)
                .animation(.easeOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            Circle().fill(color).frame(width: 10, height: 10)
        }.onAppear { pulse = true }
    }
}

// MARK: - Trip Request Overlay (matching ZipRide TripRequestOverlay exactly)
struct DTripRequestOverlay: View {
    @ObservedObject var vm: DriverViewModel
    let request: TripRequestItem
    @State private var timeLeft = 20; @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Countdown bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.eBorder).frame(height: 4)
                    RoundedRectangle(cornerRadius: 4).fill(timerColor)
                        .frame(width: geo.size.width * CGFloat(timeLeft) / 20.0, height: 4)
                        .animation(.linear(duration: 1), value: timeLeft)
                }
            }.frame(height: 4).padding(.horizontal, 24).padding(.top, 16)

            ESheetHandle().padding(.top, 10).padding(.bottom, 14)

            HStack(spacing: 6) {
                Circle().fill(Color.eGreen).frame(width: 6, height: 6)
                Text("New Trip Request").font(EFont.body(12, weight: .bold)).foregroundColor(.eGreen)
                Spacer()
                Text("\(timeLeft)s").font(EFont.display(14, weight: .heavy)).foregroundColor(timerColor)
            }.padding(.horizontal, 22).padding(.bottom, 14)

            // Fare + passenger
            HStack(spacing: 14) {
                ZStack { Circle().fill(Color.eSurface).frame(width: 52, height: 52); Text("🧑").font(.system(size: 26)) }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Passenger").font(EFont.display(16, weight: .bold)).foregroundColor(.eText)
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(i < 4 ? .eAccent : .eBorder) }
                        Text("5.00").font(EFont.body(11)).foregroundColor(.eTextMuted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("R\(Int(request.fare))").font(EFont.display(22, weight: .heavy)).foregroundColor(.eGreen)
                    Text(request.rideType.capitalized).font(EFont.body(11)).foregroundColor(.eTextMuted)
                }
            }.padding(.horizontal, 22).padding(.bottom, 16)

            // Route
            VStack(spacing: 0) {
                DTripRouteRow(dotColor: .eGreen, label: "PICKUP", address: request.pickup, detail: "~3 min away")
                Rectangle().fill(Color.eBorder).frame(width: 1, height: 16).padding(.leading, 10)
                DTripRouteRow(dotColor: .eAccent, label: "DROP-OFF", address: request.dropoff, detail: request.rideType.capitalized)
            }
            .padding(14).background(Color.eSurface)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.eBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 22).padding(.bottom, 18)

            // Accept / Decline
            HStack(spacing: 12) {
                Button { timer?.invalidate(); vm.declineTrip() } label: {
                    Text("Decline").font(EFont.body(15, weight: .semibold)).foregroundColor(.eRed)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.eRed.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.eRed.opacity(0.25), lineWidth: 1.5))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Button { timer?.invalidate(); vm.acceptTrip() } label: {
                    HStack(spacing: 8) { Image(systemName: "checkmark.circle.fill"); Text("Accept").font(EFont.body(16, weight: .bold)) }
                        .foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.eGreen).clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }.padding(.horizontal, 22).padding(.bottom, 96)
        }
        .background(Color.eCard)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.eBorder, lineWidth: 1) }
        .shadow(color: .black.opacity(0.5), radius: 40, y: -10)
        .onAppear { startCountdown() }.onDisappear { timer?.invalidate() }
    }

    private var timerColor: Color { timeLeft > 12 ? .eGreen : timeLeft > 6 ? .eAccent : .eRed }
    private func startCountdown() {
        timeLeft = 20
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if timeLeft > 0 { timeLeft -= 1 }
            else { t.invalidate(); Task { @MainActor in vm.declineTrip() } }
        }
    }
}

struct DTripRouteRow: View {
    let dotColor: Color; let label: String; let address: String; let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(dotColor).frame(width: 10, height: 10).padding(.top, 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(EFont.body(10, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.5)
                Text(address).font(EFont.body(13, weight: .semibold)).foregroundColor(.eText)
                Text(detail).font(EFont.body(11)).foregroundColor(.eTextSoft)
            }
        }.padding(.vertical, 4)
    }
}

// MARK: - En Route View (matching ZipRide DriverEnRouteView with NavInstructionBanner + TrafficAlertBanner)
struct DEnRouteView: View {
    @ObservedObject var vm: DriverViewModel
    @StateObject private var locMgr = LocationManager.shared
    @State private var region = MKCoordinateRegion(center: .init(latitude: -26.1076, longitude: 28.0567), span: .init(latitudeDelta: 0.025, longitudeDelta: 0.025))
    @State private var eta             = "—"
    @State private var distanceText    = "—"
    @State private var nextInstruction = "Head toward pickup"
    @State private var trafficLevel:   TrafficLevel = .clear
    @State private var trafficAlert:   RouteInfo?
    @State private var showAlert       = false

    var pickupCoord: CLLocationCoordinate2D? {
        guard let t = vm.currentTrip else { return nil }
        return CLLocationCoordinate2D(latitude: t.pickupLat, longitude: t.pickupLon)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Map with real traffic
            DriverRouteMap(
                driverCoord: locMgr.coordinate, targetCoord: pickupCoord,
                targetIsPickup: true, isNavigating: true,
                region: $region, eta: $eta, distanceText: $distanceText,
                nextInstruction: $nextInstruction, trafficLevel: $trafficLevel,
                onTrafficAlert: { info in trafficAlert = info; withAnimation(.spring(response: 0.4)) { showAlert = true } }
            ).ignoresSafeArea()

            // Nav banner + traffic alert
            VStack(spacing: 8) {
                DNavBanner(instruction: nextInstruction, eta: eta, distance: distanceText, traffic: trafficLevel)
                    .padding(.top, 54)
                if showAlert, let alert = trafficAlert {
                    DTrafficAlertBanner(info: alert,
                        onAccept:  { withAnimation { showAlert = false } },
                        onDismiss: { withAnimation { showAlert = false } })
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }.ignoresSafeArea(edges: .top)

            // Bottom sheet
            VStack(spacing: 0) {
                ESheetHandle().padding(.top, 12).padding(.bottom, 16)
                DStatusPill(text: "Heading to Pickup", color: .eGreen).padding(.bottom, 16)

                HStack(spacing: 14) {
                    ZStack { Circle().fill(Color.eSurface).frame(width: 56, height: 56).overlay(Circle().stroke(Color.eBorder, lineWidth: 1.5)); Text("🧑").font(.system(size: 28)) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.currentTrip?.passengerName ?? "Passenger").font(EFont.display(18, weight: .bold)).foregroundColor(.eText)
                        Text(vm.currentTrip?.rideType.capitalized ?? "Standard").font(EFont.body(12)).foregroundColor(.eTextMuted)
                    }
                    Spacer()
                    Text(vm.currentTrip?.fareStr ?? "R0").font(EFont.display(20, weight: .heavy)).foregroundColor(.eGreen)
                }.padding(.bottom, 18)

                // ETA card
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text("TO PICKUP").font(EFont.body(11, weight: .bold)).foregroundColor(.eTextSoft).kerning(0.5); Text(eta).font(EFont.display(26, weight: .heavy)).foregroundColor(.eGreen) }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) { Text("DISTANCE").font(EFont.body(11, weight: .bold)).foregroundColor(.eTextSoft).kerning(0.5); Text(distanceText).font(EFont.display(18, weight: .bold)).foregroundColor(.eText) }
                }
                .padding(16).background(Color.eSurface).overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.eBorder, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 13)).padding(.bottom, 14)

                // Pickup address
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill").font(.system(size: 22)).foregroundColor(.eGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pickup").font(EFont.body(11, weight: .bold)).foregroundColor(.eTextMuted)
                        Text(vm.currentTrip?.pickupAddress ?? "—").font(EFont.body(14, weight: .semibold)).foregroundColor(.eText)
                    }; Spacer()
                }.padding(14).background(Color.eSurface).overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.eBorder, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 13)).padding(.bottom, 14)

                HStack(spacing: 10) {
                    DActionBtn(icon: "phone.fill",   label: "Call")
                    DActionBtn(icon: "message.fill", label: "Message")
                    Button { vm.markArrived() } label: {
                        HStack(spacing: 6) { Image(systemName: "mappin.and.ellipse").font(.system(size: 13, weight: .semibold)); Text("Arrived").font(EFont.body(14, weight: .bold)) }
                            .foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.eGreen).clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 40).background(Color.eCard)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.eBorder, lineWidth: 1) }
        }
        .ignoresSafeArea().onAppear { locMgr.start() }
    }
}

// MARK: - Nav Instruction Banner (matching ZipRide NavInstructionBanner)
struct DNavBanner: View {
    let instruction: String; let eta: String; let distance: String; var traffic: TrafficLevel = .clear

    private var turnIcon: String {
        let l = instruction.lowercased()
        if l.contains("left")        { return "arrow.turn.up.left" }
        if l.contains("right")       { return "arrow.turn.up.right" }
        if l.contains("u-turn")      { return "arrow.uturn.left" }
        if l.contains("roundabout")  { return "arrow.clockwise" }
        if l.contains("arrive") || l.contains("destination") { return "mappin.circle.fill" }
        if l.contains("motorway") || l.contains("highway")   { return "arrow.up.to.line" }
        return "arrow.up"
    }
    private var accentColor: Color { switch traffic { case .heavy: return .eRed; case .moderate: return .eAccent; default: return .eGreen } }

    var body: some View {
        HStack(spacing: 14) {
            ZStack { RoundedRectangle(cornerRadius: 12).fill(accentColor).frame(width: 52, height: 52); Image(systemName: turnIcon).font(.system(size: 22, weight: .bold)).foregroundColor(.black) }
            VStack(alignment: .leading, spacing: 3) {
                Text(instruction).font(EFont.body(15, weight: .bold)).foregroundColor(.eText).lineLimit(2).minimumScaleFactor(0.8)
                HStack(spacing: 6) {
                    if traffic == .heavy {
                        HStack(spacing: 4) { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9)).foregroundColor(.eRed); Text("Heavy traffic").font(EFont.body(10, weight: .bold)).foregroundColor(.eRed) }.padding(.horizontal, 6).padding(.vertical, 2).background(Color.eRed.opacity(0.12)).clipShape(Capsule())
                    } else if traffic == .moderate {
                        HStack(spacing: 4) { Image(systemName: "clock.fill").font(.system(size: 9)).foregroundColor(.eAccent); Text("Slow traffic").font(EFont.body(10, weight: .bold)).foregroundColor(.eAccent) }.padding(.horizontal, 6).padding(.vertical, 2).background(Color.eAccent.opacity(0.12)).clipShape(Capsule())
                    }
                    Text(eta).font(EFont.body(12, weight: .semibold)).foregroundColor(.eTextSoft)
                    Text("·").foregroundColor(.eTextMuted)
                    Text(distance).font(EFont.body(12)).foregroundColor(.eTextMuted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(ZStack { RoundedRectangle(cornerRadius: 16).fill(Color.eCard); RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial).opacity(0.3) }.shadow(color: .black.opacity(0.35), radius: 12, y: 4))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(traffic == .heavy ? Color.eRed.opacity(0.4) : Color.eBorder.opacity(0.5), lineWidth: 1.5))
        .padding(.horizontal, 16)
    }
}

// MARK: - Traffic Alert Banner (matching ZipRide TrafficAlertBanner)
struct DTrafficAlertBanner: View {
    let info: RouteInfo; let onAccept: () -> Void; let onDismiss: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack { Circle().fill(Color.eRed.opacity(0.15)).frame(width: 40, height: 40); Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 18)).foregroundColor(.eRed) }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heavy Traffic Ahead").font(EFont.body(13, weight: .bold)).foregroundColor(.eText)
                    Text("Faster route saves \(info.savedMinutes) min").font(EFont.body(12)).foregroundColor(.eTextSoft)
                }
                Spacer()
                Button(action: onDismiss) { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(.eTextMuted).frame(width: 24, height: 24) }
            }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
            HStack(spacing: 10) {
                Button(action: onDismiss) { Text("Stay on Route").font(EFont.body(13, weight: .semibold)).foregroundColor(.eTextMuted).frame(maxWidth: .infinity).padding(.vertical, 11).background(Color.eSurface).overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.eBorder, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 13)) }
                Button(action: onAccept) { HStack(spacing: 6) { Image(systemName: "arrow.triangle.swap").font(.system(size: 12, weight: .bold)); Text("Faster Route").font(EFont.body(13, weight: .bold)) }.foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 11).background(Color.eGreen).clipShape(RoundedRectangle(cornerRadius: 13)) }
            }.padding(.horizontal, 14).padding(.bottom, 14)
        }
        .background(ZStack { RoundedRectangle(cornerRadius: 18).fill(Color.eCard); RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial).opacity(0.2) })
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.eRed.opacity(0.3), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6).padding(.horizontal, 16)
    }
}

// MARK: - Arrived View (matching ZipRide DriverArrivedView)
struct DArrivedView: View {
    @ObservedObject var vm: DriverViewModel
    @StateObject private var locMgr = LocationManager.shared
    @State private var waitSeconds = 0; @State private var timer: Timer?

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: .constant(MKCoordinateRegion(
                center: locMgr.coordinate ?? .init(latitude: -26.1076, longitude: 28.0567),
                span: .init(latitudeDelta: 0.008, longitudeDelta: 0.008))),
                showsUserLocation: true).ignoresSafeArea()

            VStack(spacing: 0) {
                ESheetHandle().padding(.top, 12).padding(.bottom, 16)
                DStatusPill(text: "Arrived at Pickup", color: .eAccent).padding(.bottom, 16)

                // Wait timer
                VStack(spacing: 4) {
                    Text("WAITING FOR PASSENGER").font(EFont.body(11, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.8)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(waitTimeStr).font(EFont.display(40, weight: .heavy)).foregroundColor(.eAccent)
                        Text("min").font(EFont.body(16)).foregroundColor(.eTextMuted)
                    }
                    if waitSeconds >= 120 { Text("Free waiting time exceeded — fare may adjust").font(EFont.body(11)).foregroundColor(.eRed).multilineTextAlignment(.center) }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20).background(Color.eSurface)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.eBorder, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 13)).padding(.bottom, 14)

                // Passenger
                HStack(spacing: 12) {
                    ZStack { Circle().fill(Color.eSurface).frame(width: 52, height: 52).overlay(Circle().stroke(Color.eBorder, lineWidth: 1.5)); Text("🧑").font(.system(size: 26)) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.currentTrip?.passengerName ?? "Passenger").font(EFont.display(16, weight: .bold)).foregroundColor(.eText)
                        Text(vm.currentTrip?.pickupAddress ?? "Pickup location").font(EFont.body(12)).foregroundColor(.eTextMuted).lineLimit(1)
                    }; Spacer()
                    Text(vm.currentTrip?.fareStr ?? "R0").font(EFont.display(18, weight: .heavy)).foregroundColor(.eGreen)
                }.padding(.bottom, 16)

                HStack(spacing: 10) {
                    DActionBtn(icon: "phone.fill",   label: "Call")
                    DActionBtn(icon: "message.fill", label: "Message")
                    Button { timer?.invalidate(); vm.startRide() } label: {
                        HStack(spacing: 6) { Image(systemName: "play.fill").font(.system(size: 13, weight: .bold)); Text("Start Trip").font(EFont.body(14, weight: .bold)) }
                            .foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.eGreen).clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 40).background(Color.eCard)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.eBorder, lineWidth: 1) }
        }
        .ignoresSafeArea()
        .onAppear { locMgr.start(); waitSeconds = 0; timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in waitSeconds += 1 } }
        .onDisappear { timer?.invalidate() }
    }

    private var waitTimeStr: String {
        let m = waitSeconds / 60; let s = waitSeconds % 60; return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Active Trip View (matching ZipRide DriverActiveTripView with SOS, add stop, nav banner + traffic)
struct DActiveTripView: View {
    @ObservedObject var vm: DriverViewModel
    @StateObject private var locMgr = LocationManager.shared
    @State private var region = MKCoordinateRegion(center: .init(latitude: -26.0900, longitude: 28.0760), span: .init(latitudeDelta: 0.04, longitudeDelta: 0.04))
    @State private var eta             = "—"
    @State private var distanceText    = "—"
    @State private var nextInstruction = "Head toward destination"
    @State private var trafficLevel:   TrafficLevel = .clear
    @State private var trafficAlert:   RouteInfo?
    @State private var showAlert       = false
    @State private var showPanic       = false

    var dropoffCoord: CLLocationCoordinate2D? {
        guard let t = vm.currentTrip else { return nil }
        return CLLocationCoordinate2D(latitude: t.dropoffLat, longitude: t.dropoffLon)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DriverRouteMap(
                driverCoord: locMgr.coordinate, targetCoord: dropoffCoord,
                targetIsPickup: false, isNavigating: true,
                region: $region, eta: $eta, distanceText: $distanceText,
                nextInstruction: $nextInstruction, trafficLevel: $trafficLevel,
                onTrafficAlert: { info in trafficAlert = info; withAnimation(.spring(response: 0.4)) { showAlert = true } }
            ).ignoresSafeArea()

            VStack(spacing: 8) {
                DNavBanner(instruction: nextInstruction, eta: eta, distance: distanceText, traffic: trafficLevel).padding(.top, 54)
                if showAlert, let alert = trafficAlert {
                    DTrafficAlertBanner(info: alert,
                        onAccept:  { withAnimation { showAlert = false } },
                        onDismiss: { withAnimation { showAlert = false } })
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }.ignoresSafeArea(edges: .top)

            bottomSheet
        }
        .ignoresSafeArea()
        .onAppear { locMgr.start() }
        .alert("🚨 Panic / Emergency?", isPresented: $showPanic) {
            Button("Trigger SOS", role: .destructive) {
                if let coord = locMgr.coordinate {
                    let lat = coord.latitude
                    let lon = coord.longitude
                    Task { await vm.triggerPanic(lat: lat, lon: lon) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This will alert emergency contacts and admins with your live location.") }
    }

    @ViewBuilder private var bottomSheet: some View {
        VStack(spacing: 0) {
            ESheetHandle().padding(.top, 12).padding(.bottom, 6)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ETA + earning
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TO DROP-OFF").font(EFont.body(11, weight: .bold)).foregroundColor(.eTextSoft).kerning(0.5)
                            Text(eta).font(EFont.display(22, weight: .heavy)).foregroundColor(.eText)
                            Text(distanceText + " remaining").font(EFont.body(11)).foregroundColor(.eTextMuted)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Earning").font(EFont.body(11)).foregroundColor(.eTextMuted)
                            Text(vm.currentTrip?.fareStr ?? "R0").font(EFont.display(20, weight: .heavy)).foregroundColor(.eGreen)
                        }
                    }.padding(.bottom, 12)

                    // Passenger row
                    if let pname = vm.currentTrip?.passengerName {
                        HStack(spacing: 12) {
                            ZStack { Circle().fill(Color.eSurface).frame(width: 40, height: 40); Text("🧑").font(.system(size: 20)) }
                            VStack(alignment: .leading) {
                                Text(pname).font(EFont.body(13, weight: .semibold)).foregroundColor(.eText)
                                Text(vm.currentTrip?.dropoffAddress ?? "—").font(EFont.body(11)).foregroundColor(.eTextSoft).lineLimit(1)
                            }
                            Spacer()
                            HStack(spacing: 6) { DSqBtn(icon: "phone.fill"); DSqBtn(icon: "message.fill") }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12).background(Color.eSurface)
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.eBorder, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 13)).padding(.bottom, 12)
                    }
                }.padding(.horizontal, 20)
            }.frame(maxHeight: 220)

            // Action buttons
            HStack(spacing: 10) {
                Button { showPanic = true } label: {
                    HStack(spacing: 6) { Image(systemName: "shield.fill"); Text("SOS") }
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.eRed)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color.eRed.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.eRed.opacity(0.2), lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 13))
                }
                Button { vm.completeRide() } label: {
                    Text("Complete Trip ✓").font(EFont.body(14, weight: .bold)).foregroundColor(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color.eGreen).clipShape(RoundedRectangle(cornerRadius: 13))
                }
            }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 36)
        }
        .background(Color.eCard)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.eBorder, lineWidth: 1) }
    }
}

// MARK: - Trip Complete View (matching ZipRide DriverTripCompleteView)
struct DTripCompleteView: View {
    @ObservedObject var vm: DriverViewModel
    @State private var rating     = 5
    @State private var tags:      Set<String> = []
    @State private var amountVis  = false
    private let paxTags = ["On time","Clean trip","Good behaviour","Safe route","Great tip","Quiet trip"]

    var earned: Double { vm.currentTrip?.driverEarnings ?? vm.currentTrip?.totalFare ?? 0 }
    var distKm: Double { vm.currentTrip?.estimatedDistanceKm ?? 0 }

    var body: some View {
        ZStack { Color.eBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero
                    ZStack {
                        LinearGradient(colors: [Color(hex: "#0A1F14"), Color(hex: "#0A1018")], startPoint: .topLeading, endPoint: .bottomTrailing).frame(height: 200)
                        VStack(spacing: 8) {
                            ZStack { Circle().fill(Color.eGreen.opacity(0.15)).frame(width: 72, height: 72); Image(systemName: "checkmark.circle.fill").font(.system(size: 38)).foregroundColor(.eGreen) }
                                .scaleEffect(amountVis ? 1 : 0.4).opacity(amountVis ? 1 : 0)
                            Text("Trip Complete!").font(EFont.display(22, weight: .heavy)).foregroundColor(.eText)
                            Text("Great work, \(vm.user.firstName)!").font(EFont.body(13)).foregroundColor(.eTextSoft)
                        }
                    }

                    // Earnings
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("YOU EARNED").font(EFont.body(11, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.8)
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text("R").font(EFont.display(18, weight: .bold)).foregroundColor(.eGreen).baselineOffset(10)
                                    Text(String(format: "%.0f", earned)).font(EFont.display(44, weight: .heavy)).foregroundColor(.eText).kerning(-2)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 8) {
                                HStack(spacing: 5) { Text("📏").font(.system(size: 12)); Text(String(format: "%.1f km", distKm)).font(EFont.body(12, weight: .semibold)).foregroundColor(.eText) }.padding(.horizontal, 10).padding(.vertical, 5).background(Color.eSurface).overlay(Capsule().stroke(Color.eBorder, lineWidth: 1)).clipShape(Capsule())
                                HStack(spacing: 5) { Text("⭐").font(.system(size: 12)); Text("5.00").font(EFont.body(12, weight: .semibold)).foregroundColor(.eText) }.padding(.horizontal, 10).padding(.vertical, 5).background(Color.eSurface).overlay(Capsule().stroke(Color.eBorder, lineWidth: 1)).clipShape(Capsule())
                            }
                        }
                        .padding(20).opacity(amountVis ? 1 : 0).offset(y: amountVis ? 0 : 20)

                        Divider().background(Color.eBorder)

                        // Fare breakdown
                        VStack(spacing: 0) {
                            DFareRow("Base fare", "R\(String(format: "%.0f", earned * 0.5))")
                            DFareRow("Platform fee (20%)", "-R\(String(format: "%.0f", (vm.currentTrip?.totalFare ?? 0) * 0.20))", accent: .eRed)
                            Divider().background(Color.eBorder).padding(.vertical, 4)
                            DFareRow("Your earnings", "R\(String(format: "%.0f", earned))", accent: .eGreen, bold: true)
                        }.padding(.horizontal, 20).padding(.bottom, 16)
                    }
                    .background(Color.eCard).overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.eBorder, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 20).padding(.top, 16)

                    // Trip info
                    VStack(spacing: 0) {
                        DInfoRow(icon: "location.fill", color: .eGreen, label: "Pickup", value: vm.currentTrip?.pickupAddress ?? "—")
                        Divider().background(Color.eBorder).padding(.leading, 52)
                        DInfoRow(icon: "flag.checkered", color: .eAccent, label: "Drop-off", value: vm.currentTrip?.dropoffAddress ?? "—")
                        if let pax = vm.currentTrip?.passengerName {
                            Divider().background(Color.eBorder).padding(.leading, 52)
                            DInfoRow(icon: "person.fill", color: Color(hex: "#4488FF"), label: "Passenger", value: pax)
                        }
                    }
                    .background(Color.eCard).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.eBorder, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20).padding(.top, 12)

                    // Rate passenger
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RATE YOUR PASSENGER").font(EFont.body(11, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.8)
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { i in
                                Button { withAnimation(.spring(response: 0.3)) { rating = i } } label: {
                                    Image(systemName: i <= rating ? "star.fill" : "star").font(.system(size: 34))
                                        .foregroundColor(i <= rating ? .eAccent : .eBorder)
                                        .scaleEffect(i == rating ? 1.2 : 1.0).animation(.spring(response: 0.2), value: rating)
                                }
                            }
                        }.frame(maxWidth: .infinity)
                        // Tag chips
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) { ForEach(paxTags.prefix(3), id: \.self) { t in DRatingTag(tag: t, sel: tags.contains(t)) { if tags.contains(t) { tags.remove(t) } else { tags.insert(t) } } } }
                            HStack(spacing: 8) { ForEach(Array(paxTags.dropFirst(3)), id: \.self) { t in DRatingTag(tag: t, sel: tags.contains(t)) { if tags.contains(t) { tags.remove(t) } else { tags.insert(t) } } } }
                        }
                    }
                    .padding(18).background(Color.eCard).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.eBorder, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20).padding(.top, 12)

                    VStack(spacing: 10) {
                        Button { vm.dismissTripComplete() } label: { Text("Submit Rating").font(EFont.body(16, weight: .bold)).foregroundColor(.black).frame(maxWidth: .infinity).frame(height: 54).background(Color.eGreen).clipShape(RoundedRectangle(cornerRadius: 16)) }
                        Button { vm.dismissTripComplete() } label: { Text("Skip").font(EFont.body(14)).foregroundColor(.eTextMuted).frame(maxWidth: .infinity).frame(height: 44) }
                    }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 48)
                }
            }
        }
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.2)) { amountVis = true } }
    }
}

// MARK: - Driver Trips View (matching ZipRide DriverTripsView)
struct DTripsView: View {
    @ObservedObject var vm: DriverViewModel
    var body: some View {
        ZStack { Color.eBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("My Trips").font(EFont.display(26, weight: .heavy)).foregroundColor(.eText).kerning(-0.5).padding(.top, 54).padding(.bottom, 20)
                    if vm.tripHistory.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "car.fill").font(.system(size: 40)).foregroundColor(.eTextMuted.opacity(0.3))
                            Text("No trips yet").font(EFont.display(18, weight: .bold)).foregroundColor(.eText)
                            Text("Your completed trips will appear here").font(EFont.body(13)).foregroundColor(.eTextMuted)
                        }.frame(maxWidth: .infinity).padding(.vertical, 60)
                    } else {
                        VStack(spacing: 10) { ForEach(vm.tripHistory) { DDriverTripCard(trip: $0) } }
                    }
                    Spacer(minLength: 100)
                }.padding(.horizontal, 20)
            }
        }.task { await vm.loadHistory() }
    }
}

struct DDriverTripCard: View {
    let trip: BETrip
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack { RoundedRectangle(cornerRadius: 10).fill(Color.eSurface).frame(width: 44, height: 44); Image(systemName: trip.status.contains("cancel") ? "xmark.circle" : "checkmark.circle.fill").font(.system(size: 20)).foregroundColor(trip.status.contains("cancel") ? .eRed : .eGreen) }
                VStack(alignment: .leading, spacing: 3) { Text(trip.passengerName ?? "Passenger").font(EFont.body(14, weight: .semibold)).foregroundColor(.eText); Text(trip.statusLabel).font(EFont.body(12)).foregroundColor(.eTextMuted) }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) { Text("R\(Int(trip.driverEarnings ?? trip.totalFare ?? 0))").font(EFont.display(16, weight: .heavy)).foregroundColor(.eGreen); if let d = trip.estimatedDistanceKm { Text(String(format: "%.1f km", d)).font(EFont.body(11)).foregroundColor(.eTextMuted) } }
            }.padding(14)
            Divider().background(Color.eBorder).padding(.horizontal, 14)
            HStack(spacing: 8) { Circle().fill(Color.eGreen).frame(width: 6, height: 6); Text(trip.pickupAddress).font(EFont.body(12)).foregroundColor(.eTextSoft).lineLimit(1) }.padding(.horizontal, 14).padding(.vertical, 8)
            HStack(spacing: 8) { Circle().fill(Color.eAccent).frame(width: 6, height: 6); Text(trip.dropoffAddress).font(EFont.body(12)).foregroundColor(.eTextSoft).lineLimit(1) }.padding(.horizontal, 14).padding(.bottom, 12)
        }
        .background(Color.eCard).overlay(RoundedRectangle(cornerRadius: 16).stroke(trip.status.contains("cancel") ? Color.eRed.opacity(0.15) : Color.eBorder, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 16)).opacity(trip.status.contains("cancel") ? 0.7 : 1)
    }
}

// MARK: - Earnings View (matching ZipRide DriverEarningsView)
struct DEarningsView: View {
    @ObservedObject var vm: DriverViewModel
    @State private var period = 0
    private let periods = ["Today", "This Week", "This Month"]

    private var amount: String {
        switch period {
        case 0:  return vm.earnings?.today    ?? "R0"
        case 1:  return vm.earnings?.thisWeek ?? "R0"
        default: return vm.earnings?.thisMonth ?? "R0"
        }
    }

    var body: some View {
        ZStack {
            Color.eBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Earnings")
                        .font(EFont.display(26, weight: .heavy)).foregroundColor(.eText)
                        .kerning(-0.5).padding(.top, 54).padding(.bottom, 20)
                    periodSelector
                    heroCard
                    statsCard
                    Spacer(minLength: 100)
                }.padding(.horizontal, 20)
            }
        }.task { await vm.loadEarnings() }
    }

    private var periodSelector: some View {
        HStack(spacing: 8) {
            ForEach(periods.indices, id: \.self) { i in
                Button { withAnimation { period = i } } label: {
                    Text(periods[i])
                        .font(EFont.body(13, weight: period==i ? .bold : .semibold))
                        .foregroundColor(period==i ? .black : .eTextSoft)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(period==i ? Color.eGreen : Color.clear)
                        .overlay(Capsule().stroke(period==i ? Color.clear : Color.eBorder, lineWidth: 1.5))
                        .clipShape(Capsule())
                }
            }
        }.padding(.bottom, 20)
    }

    private var heroCard: some View {
        VStack(spacing: 6) {
            Text("EARNED").font(EFont.body(12, weight: .semibold)).foregroundColor(.eTextSoft).kerning(1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("R").font(EFont.display(24, weight: .bold)).foregroundColor(.eGreen).baselineOffset(14)
                Text(amount.replacingOccurrences(of: "R", with: ""))
                    .font(EFont.display(54, weight: .heavy)).foregroundColor(.eText).kerning(-2)
            }
            if let trips = vm.earnings?.totalTrips {
                Text("\(trips) total trips").font(EFont.body(13)).foregroundColor(.eTextMuted)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
        .background(Color.eCard)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.eBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 24)).padding(.bottom, 20)
    }

    private var statsCard: some View {
        VStack(spacing: 0) {
            statRow("Total Earned", vm.earnings?.totalEarned ?? "R0")
            statRow("Avg Per Trip",  vm.earnings?.avgPerTrip  ?? "R0")
            statRow("Total Trips",   vm.earnings?.totalTrips.map { "\($0)" } ?? "0")
        }
        .background(Color.eCard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.eBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(EFont.body(14)).foregroundColor(.eTextSoft)
            Spacer()
            Text(value).font(EFont.body(14, weight: .semibold)).foregroundColor(.eText)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.eBorder).frame(height: 1) }
    }
}


// MARK: - Driver Profile View (matching ZipRide DriverProfileView)
struct DProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var vm: DriverViewModel
    @State private var showSignOut = false

    var user: UserEntity { vm.user }
    var isVerified: Bool { vm.profile?.isVerified ?? false }

    var body: some View {
        ZStack { Color.eBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero
                    ZStack(alignment: .bottom) {
                        LinearGradient(colors: [Color(hex: "#0A1F14"), Color(hex: "#0A1018")], startPoint: .topLeading, endPoint: .bottomTrailing).frame(height: 270)
                        HStack {
                            HStack(spacing: 6) {
                                Circle().fill(vm.isOnline ? Color.eGreen : Color.eTextMuted).frame(width: 8, height: 8)
                                Text(vm.isOnline ? "Online" : "Offline").font(EFont.body(12, weight: .bold)).foregroundColor(vm.isOnline ? .eGreen : .eTextMuted)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7).background((vm.isOnline ? Color.eGreen : Color.eTextMuted).opacity(0.1))
                            .overlay(Capsule().stroke((vm.isOnline ? Color.eGreen : Color.eTextMuted).opacity(0.25), lineWidth: 1)).clipShape(Capsule())
                            Spacer()
                            Image(systemName: "bell.fill").font(.system(size: 17)).foregroundColor(.eText).frame(width: 38, height: 38).background(Color.eSurface).clipShape(Circle())
                        }.padding(.horizontal, 20).frame(maxHeight: .infinity, alignment: .top).padding(.top, 54)

                        VStack(spacing: 10) {
                            ZStack {
                                Circle().fill(LinearGradient(colors: [Color(hex:"#1C2535"), Color(hex:"#252B38")], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 90, height: 90)
                                    .overlay(Circle().stroke(isVerified ? Color.eGreen : Color.eAccent, lineWidth: 3))
                                Text(user.initials).font(EFont.display(32, weight: .heavy)).foregroundColor(.eAccent)
                            }.shadow(color: Color.eAccent.opacity(0.3), radius: 20)
                            HStack(spacing: 6) {
                                Text(user.fullName).font(EFont.display(20, weight: .heavy)).foregroundColor(.eText)
                                if isVerified { Image(systemName: "checkmark.seal.fill").font(.system(size: 16)).foregroundColor(.eGreen) }
                            }
                            if let code = vm.profile?.driverCode, !code.isEmpty { Text("Code: \(code)").font(EFont.body(12)).foregroundColor(.eTextSoft) }
                            HStack(spacing: 5) { Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(.eAccent); Text("5.00").font(EFont.body(13, weight: .bold)).foregroundColor(.eAccent) }
                                .padding(.horizontal, 14).padding(.vertical, 5).background(Color.eAccent.opacity(0.1))
                                .overlay(Capsule().stroke(Color.eAccent.opacity(0.2), lineWidth: 1)).clipShape(Capsule())
                        }.padding(.bottom, 20)
                    }

                    // Stats
                    HStack(spacing: 0) {
                        DProfileStat("\(vm.tripHistory.count)", "Trips", .eGreen); Rectangle().fill(Color.eBorder).frame(width: 1, height: 50)
                        DProfileStat("R\(Int(vm.earnings?.totalEarnedNum ?? 0))", "Earned", .eAccent); Rectangle().fill(Color.eBorder).frame(width: 1, height: 50)
                        DProfileStat("100%", "Acceptance", Color(hex: "#4488FF"))
                    }.background(Color.eCard).overlay(alignment: .bottom) { Rectangle().fill(Color.eBorder).frame(height: 1) }

                    // Driver section
                    DProfSection("DRIVER")
                    DProfRow(icon: "car.fill",         bg: .eGreen,              title: "Vehicle Information",  sub: vm.profile?.vehicleDisplay ?? "No vehicle on file") {}
                    DProfRow(icon: "doc.fill",         bg: Color(hex:"#4488FF"), title: "My Documents",         sub: "Tap to view document status") {}
                    DProfRow(icon: "building.2.fill",  bg: Color(hex:"#1A8FE3"), title: "Bank Account",         sub: "Not added") {}

                    // Service preferences card
                    DServicePreferencesCard(vm: vm)

                    // Account section
                    DProfSection("ACCOUNT")
                    DProfRow(icon: "bell.fill",               bg: .eAccent,           title: "Notifications",    sub: "Manage alerts") {}
                    DProfRow(icon: "shield.fill",             bg: .eRed,              title: "Safety Settings",  sub: "Panic button, emergency contacts") {}
                    DProfRow(icon: "questionmark.circle.fill", bg: Color(hex:"#555"), title: "Help & Support",   sub: "FAQs, contact support") {}
                    DProfRow(icon: "doc.text.fill",           bg: Color(hex:"#444"), title: "Terms & Privacy",   sub: "Read our policies") {}

                    Button { showSignOut = true } label: {
                        HStack(spacing: 12) {
                            ZStack { RoundedRectangle(cornerRadius: 8).fill(Color.eRed.opacity(0.12)).frame(width: 34, height: 34); Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 14)).foregroundColor(.eRed) }
                            Text("Sign Out").font(EFont.body(14, weight: .semibold)).foregroundColor(.eRed); Spacer()
                        }.padding(.horizontal, 20).padding(.vertical, 14).background(Color.eCard)
                    }.padding(.top, 10)

                    Text("eTaxi v1.0 · ZA Driver Edition").font(EFont.body(11)).foregroundColor(.eTextMuted).frame(maxWidth: .infinity).padding(.vertical, 16)
                    Spacer(minLength: 100)
                }
            }
        }
        .task { await vm.loadProfile() }
        .alert("Sign Out", isPresented: $showSignOut) {
            Button("Sign Out", role: .destructive) { authVM.logout() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Are you sure you want to sign out?") }
    }
}

struct DProfileStat: View {
    let val: String; let label: String; let color: Color
    init(_ val: String, _ label: String, _ color: Color) { self.val=val; self.label=label; self.color=color }
    var body: some View { VStack(spacing:4){Text(val).font(EFont.display(18,weight:.heavy)).foregroundColor(color);Text(label).font(EFont.body(11)).foregroundColor(.eTextMuted)}.frame(maxWidth:.infinity).padding(.vertical,18) }
}
struct DProfSection: View {
    let t: String; init(_ t: String) { self.t=t }
    var body: some View { Text(t).font(EFont.body(11,weight:.bold)).foregroundColor(.eTextMuted).kerning(0.8).frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,20).padding(.top,20).padding(.bottom,6) }
}
struct DProfRow: View {
    let icon:String;let bg:Color;let title:String;let sub:String;var badge:String?=nil;let action:()->Void
    var body: some View {
        Button(action:action){HStack(spacing:14){ZStack{RoundedRectangle(cornerRadius:8).fill(bg.opacity(0.15)).frame(width:36,height:36);Image(systemName:icon).font(.system(size:15)).foregroundColor(bg)};VStack(alignment:.leading,spacing:2){HStack(spacing:6){Text(title).font(EFont.body(14,weight:.semibold)).foregroundColor(.eText);if let b=badge{Text(b).font(EFont.body(9,weight:.bold)).foregroundColor(.eRed).padding(.horizontal,5).padding(.vertical,2).background(Color.eRed.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius:4))}};Text(sub).font(EFont.body(12)).foregroundColor(.eTextMuted).lineLimit(1)};Spacer();Image(systemName:"chevron.right").font(.system(size:12,weight:.semibold)).foregroundColor(.eTextMuted.opacity(0.5))}.padding(.horizontal,20).padding(.vertical,13).background(Color.eCard)}
        .overlay(alignment:.bottom){Rectangle().fill(Color.eBorder.opacity(0.5)).frame(height:0.5).padding(.leading,70)}
    }
}

// MARK: - Driver Service Preferences Card (matching ZipRide DriverServicePreferencesCard)
struct DServicePreferencesCard: View {
    @ObservedObject var vm: DriverViewModel
    @State private var acceptsStandard = true
    @State private var acceptsCustom   = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack { RoundedRectangle(cornerRadius: 8).fill(Color(hex:"#4488FF").opacity(0.12)).frame(width: 34, height: 34); Image(systemName: "slider.horizontal.3").font(.system(size: 14)).foregroundColor(Color(hex:"#4488FF")) }
                VStack(alignment: .leading, spacing: 1) { Text("Trip Types").font(EFont.body(14, weight: .semibold)).foregroundColor(.eText); Text("Choose which trips you accept").font(EFont.body(11)).foregroundColor(.eTextMuted) }; Spacer()
            }.padding(.horizontal, 20).padding(.vertical, 14).background(Color.eCard)
            Divider().background(Color.eBorder)
            DServiceToggleRow(icon: "bolt.fill", color: .eGreen, title: "Standard Rides", sub: "On-demand metered trips", badge: "Per km + time", isOn: acceptsStandard, canOff: acceptsCustom) { if !(acceptsStandard && !acceptsCustom) { acceptsStandard.toggle() } }
            Divider().background(Color.eBorder).padding(.horizontal, 20)
            DServiceToggleRow(icon: "clock.fill", color: Color(hex:"#6366F1"), title: "Custom Hire", sub: "Hourly & daily flat-rate packages", badge: "Flat rate", isOn: acceptsCustom, canOff: acceptsStandard) { if !(acceptsCustom && !acceptsStandard) { acceptsCustom.toggle() } }
            if !acceptsStandard && !acceptsCustom {
                HStack(spacing: 6) { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundColor(.eRed); Text("You must accept at least one trip type").font(EFont.body(11, weight: .semibold)).foregroundColor(.eRed) }.padding(.horizontal, 20).padding(.vertical, 10).background(Color.eRed.opacity(0.06))
            }
        }
        .background(Color.eCard).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.eBorder, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20).padding(.top, 10)
    }
}

struct DServiceToggleRow: View {
    let icon:String; let color:Color; let title:String; let sub:String; let badge:String; let isOn:Bool; let canOff:Bool; let action:()->Void
    var body: some View {
        HStack(spacing: 14) {
            ZStack { Circle().fill(color.opacity(0.12)).frame(width:36,height:36); Image(systemName:icon).font(.system(size:14)).foregroundColor(color) }
            VStack(alignment:.leading,spacing:2){ HStack(spacing:6){Text(title).font(EFont.body(13,weight:.semibold)).foregroundColor(.eText);Text(badge).font(EFont.body(9,weight:.bold)).foregroundColor(color).padding(.horizontal,5).padding(.vertical,2).background(color.opacity(0.1)).clipShape(Capsule())};Text(sub).font(EFont.body(11)).foregroundColor(.eTextMuted) }
            Spacer()
            Toggle("", isOn: Binding(get:{isOn}, set:{_ in if isOn && !canOff{return}; action()})).toggleStyle(SwitchToggleStyle(tint: color)).labelsHidden().opacity(isOn && !canOff ? 0.4:1)
        }.padding(.horizontal,20).padding(.vertical,14).background(Color.eCard)
    }
}

// MARK: - Shared helpers
struct DActionBtn: View {
    let icon: String; let label: String; var tint: Color = .eText
    var body: some View {
        Button {} label: { HStack(spacing:8){Image(systemName:icon).font(.system(size:14,weight:.semibold));Text(label).font(EFont.body(13,weight:.semibold))}.foregroundColor(tint).frame(maxWidth:.infinity).padding(.vertical,14).background(Color.eSurface).overlay(RoundedRectangle(cornerRadius:13).stroke(Color.eBorder,lineWidth:1.5)).clipShape(RoundedRectangle(cornerRadius:13)) }
    }
}
struct DSqBtn: View {
    let icon: String
    var body: some View { Button {} label: { Image(systemName:icon).font(.system(size:14)).foregroundColor(.eTextMuted).frame(width:36,height:36).background(Color.eSurface).overlay(RoundedRectangle(cornerRadius:8).stroke(Color.eBorder,lineWidth:1)).clipShape(RoundedRectangle(cornerRadius:8)) } }
}
struct DStatusPill: View {
    let text: String; let color: Color
    var body: some View { HStack(spacing:6){Circle().fill(color).frame(width:6,height:6);Text(text).font(EFont.body(12,weight:.bold)).foregroundColor(color)}.padding(.horizontal,14).padding(.vertical,7).background(color.opacity(0.08)).overlay(Capsule().stroke(color.opacity(0.2),lineWidth:1)).clipShape(Capsule()) }
}
struct DFareRow: View {
    let label:String;let value:String;var accent:Color = .eTextSoft;var bold:Bool=false
    init(_ l:String,_ v:String,accent:Color = .eTextSoft,bold:Bool=false){label=l;value=v;self.accent=accent;self.bold=bold}
    var body: some View { HStack{Text(label).font(EFont.body(13,weight:bold ? .bold:.regular)).foregroundColor(bold ? .eText:.eTextSoft);Spacer();Text(value).font(EFont.body(13,weight:bold ? .heavy:.semibold)).foregroundColor(bold ? .eGreen:accent)}.padding(.horizontal,20).padding(.vertical,10) }
}
struct DInfoRow: View {
    let icon:String;let color:Color;let label:String;let value:String
    var body: some View { HStack(spacing:14){ZStack{RoundedRectangle(cornerRadius:8).fill(color.opacity(0.12)).frame(width:32,height:32);Image(systemName:icon).font(.system(size:13)).foregroundColor(color)};VStack(alignment:.leading,spacing:1){Text(label).font(EFont.body(10,weight:.bold)).foregroundColor(.eTextMuted).kerning(0.5);Text(value).font(EFont.body(13)).foregroundColor(.eText).lineLimit(1)};Spacer()}.padding(.horizontal,16).padding(.vertical,12) }
}
struct DRatingTag: View {
    let tag:String;let sel:Bool;let action:()->Void
    var body: some View { Button(action:action){Text(tag).font(EFont.body(12,weight:.semibold)).foregroundColor(sel ? .eGreen:.eTextSoft).padding(.horizontal,12).padding(.vertical,7).background(sel ? Color.eGreen.opacity(0.1):Color.eSurface).overlay(Capsule().stroke(sel ? Color.eGreen.opacity(0.3):Color.eBorder,lineWidth:1)).clipShape(Capsule())} }
}

// MARK: - DriverRouteMap (ZipRide's full implementation with real traffic)
enum TrafficLevel: Equatable { case clear, moderate, heavy, unknown }
final class TrafficPolyline: MKPolyline {
    var trafficLevel: TrafficLevel = .clear; var isAlternate: Bool = false
    convenience init(points: UnsafePointer<MKMapPoint>, count: Int, trafficLevel: TrafficLevel, isAlternate: Bool) {
        self.init(points: points, count: count); self.trafficLevel = trafficLevel; self.isAlternate = isAlternate
    }
}
struct RouteInfo { let eta: String; let distance: String; let trafficLevel: TrafficLevel; let savedMinutes: Int }

struct DriverRouteMap: UIViewRepresentable {
    var driverCoord:    CLLocationCoordinate2D?
    var targetCoord:    CLLocationCoordinate2D?
    var targetIsPickup: Bool
    var isNavigating:   Bool = true
    var waypoints:      [TripStop] = []
    @Binding var region:          MKCoordinateRegion
    @Binding var eta:             String
    @Binding var distanceText:    String
    @Binding var nextInstruction: String
    @Binding var trafficLevel:    TrafficLevel
    var onTrafficAlert: ((RouteInfo) -> Void)?
    var onRouteUpdated: ((TrafficLevel) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(); map.delegate = context.coordinator; map.showsUserLocation = true
        map.showsCompass = true; map.showsTraffic = true; map.mapType = .standard
        map.pointOfInterestFilter = .includingAll
        map.userTrackingMode = isNavigating ? .followWithHeading : .none; return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        guard let target = targetCoord else { return }
        let co = context.coordinator
        let targetChanged  = co.lastTarget.map { dist($0, target) > 5 } ?? true
        let driverMoved    = driverCoord.flatMap { n in co.lastDriverCoord.map { dist($0, n) > 50 } } ?? (driverCoord != nil)
        let wpChanged      = co.lastWpCount != waypoints.count
        if isNavigating && map.userTrackingMode != .followWithHeading { map.userTrackingMode = .followWithHeading }
        if targetChanged || driverMoved || wpChanged {
            co.lastTarget = target; co.lastDriverCoord = driverCoord; co.lastWpCount = waypoints.count
            co.onTrafficAlert = onTrafficAlert; co.onRouteUpdated = onRouteUpdated
            co.fetchRoute(on: map, from: driverCoord, waypoints: waypoints, to: target, isPickup: targetIsPickup, fitRoute: !isNavigating, etaB: $eta, distB: $distanceText, instrB: $nextInstruction, trafficB: $trafficLevel)
        }
    }
    func makeCoordinator() -> Coord { Coord() }
    private func dist(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    final class Coord: NSObject, MKMapViewDelegate {
        var lastTarget: CLLocationCoordinate2D?; var lastDriverCoord: CLLocationCoordinate2D?; var lastWpCount = 0
        var onTrafficAlert: ((RouteInfo) -> Void)?; var onRouteUpdated: ((TrafficLevel) -> Void)?
        private var isRouting = false; private var lastAlertDate: Date?; private var lastReportedTraffic: TrafficLevel = .unknown

        func fetchRoute(on map: MKMapView, from origin: CLLocationCoordinate2D?, waypoints: [TripStop], to dest: CLLocationCoordinate2D, isPickup: Bool, fitRoute: Bool, etaB: Binding<String>, distB: Binding<String>, instrB: Binding<String>, trafficB: Binding<TrafficLevel>) {
            guard !isRouting else { return }; isRouting = true
            map.removeOverlays(map.overlays); map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
            for stop in waypoints { let p = MKPointAnnotation(); p.coordinate = stop.coordinate; p.title = stop.name; map.addAnnotation(p) }
            let destPin = MKPointAnnotation(); destPin.coordinate = dest; destPin.title = isPickup ? "Pickup" : "Drop-off"; map.addAnnotation(destPin)
            let req = MKDirections.Request(); req.transportType = .automobile; req.requestsAlternateRoutes = true; req.departureDate = Date()
            req.source = origin.map { MKMapItem(placemark: MKPlacemark(coordinate: $0)) } ?? .forCurrentLocation()
            req.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
            MKDirections(request: req).calculate { [weak self] resp, _ in
                guard let self else { return }; self.isRouting = false
                DispatchQueue.main.async {
                    guard let routes = resp?.routes, !routes.isEmpty else {
                        etaB.wrappedValue = "—"; distB.wrappedValue = "—"; instrB.wrappedValue = "Head toward \(isPickup ? "pickup" : "destination")"; trafficB.wrappedValue = .unknown; return
                    }
                    let best  = routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime })!
                    let worst = routes.max(by: { $0.expectedTravelTime < $1.expectedTravelTime })!
                    let traffic   = self.estimateTraffic(best)
                    let savedMins = Int((worst.expectedTravelTime - best.expectedTravelTime) / 60)
                    for route in routes where route !== best {
                        let alt = TrafficPolyline(points: route.polyline.points(), count: route.polyline.pointCount, trafficLevel: .unknown, isAlternate: true); map.addOverlay(alt, level: .aboveRoads)
                    }
                    let bestLine = TrafficPolyline(points: best.polyline.points(), count: best.polyline.pointCount, trafficLevel: traffic, isAlternate: false); map.addOverlay(bestLine, level: .aboveRoads)
                    if fitRoute { map.setVisibleMapRect(best.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top:80,left:40,bottom:340,right:40), animated: true) }
                    let mins = Int(best.expectedTravelTime / 60)
                    etaB.wrappedValue = mins <= 0 ? "< 1 min" : "\(mins) min"
                    let km = best.distance / 1000; distB.wrappedValue = km < 1 ? "\(Int(best.distance)) m" : String(format: "%.1f km", km)
                    instrB.wrappedValue = best.steps.first { !$0.instructions.isEmpty && !$0.instructions.lowercased().hasPrefix("depart") }?.instructions ?? "Head toward \(isPickup ? "pickup" : "destination")"
                    trafficB.wrappedValue = traffic; self.onRouteUpdated?(traffic)
                    let now = Date(); let last = self.lastAlertDate ?? .distantPast
                    if traffic == .heavy && savedMins > 2 && now.timeIntervalSince(last) > 120 {
                        self.lastAlertDate = now
                        self.onTrafficAlert?(RouteInfo(eta: etaB.wrappedValue, distance: distB.wrappedValue, trafficLevel: traffic, savedMinutes: savedMins))
                    }
                }
            }
        }
        private func estimateTraffic(_ route: MKRoute) -> TrafficLevel {
            let ff = route.distance / 13.9; let r = route.expectedTravelTime / max(ff, 1)
            if r > 2.0 { return .heavy }; if r > 1.35 { return .moderate }; return .clear
        }
        func mapView(_ mv: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? TrafficPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKPolylineRenderer(polyline: poly); r.lineCap = .round; r.lineJoin = .round
            if poly.isAlternate { r.lineWidth = 4; r.strokeColor = UIColor.systemGray.withAlphaComponent(0.4); r.lineDashPattern = [8,6] }
            else {
                r.lineWidth = 7
                switch poly.trafficLevel {
                case .clear:    r.strokeColor = UIColor(red:0, green:0.898, blue:0.455, alpha:1)
                case .moderate: r.strokeColor = UIColor(red:1, green:0.75,  blue:0,     alpha:1)
                case .heavy:    r.strokeColor = UIColor(red:0.98, green:0.27, blue:0.27, alpha:1)
                case .unknown:  r.strokeColor = UIColor(red:0, green:0.898, blue:0.455, alpha:0.6)
                }
            }
            return r
        }
        func mapView(_ mv: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let v = (mv.dequeueReusableAnnotationView(withIdentifier: "pin") ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin"))
            if let m = v as? MKMarkerAnnotationView {
                m.annotation = annotation; let t = annotation.title ?? ""
                if t == "Pickup"   { m.glyphImage = UIImage(systemName:"figure.wave"); m.markerTintColor = UIColor(red:0,green:0.898,blue:0.455,alpha:1) }
                else if t == "Drop-off" { m.glyphImage = UIImage(systemName:"flag.checkered"); m.markerTintColor = UIColor(red:1,green:0.6,blue:0,alpha:1) }
                else { m.glyphImage = UIImage(systemName:"mappin.circle.fill"); m.markerTintColor = UIColor(red:0.6,green:0.4,blue:1,alpha:1) }
                m.canShowCallout = true
            }; return v
        }
    }
}

// MARK: - TripStop model
struct TripStop: Identifiable, Equatable {
    let id: UUID; let name: String; let address: String; let coordinate: CLLocationCoordinate2D
    init(name: String, address: String, coordinate: CLLocationCoordinate2D) { id = UUID(); self.name=name; self.address=address; self.coordinate=coordinate }
    static func == (l: TripStop, r: TripStop) -> Bool { l.id == r.id }
}

// MARK: - ETaxiMap for passenger screens (simple version using DriverRouteMap)
struct ETaxiMap: UIViewRepresentable {
    var origin: CLLocationCoordinate2D?; var target: CLLocationCoordinate2D?
    var isPickup: Bool; var fitRoute: Bool
    @Binding var eta: String; @Binding var distance: String; @Binding var traffic: TrafficLevel

    func makeUIView(context: Context) -> MKMapView {
        let m = MKMapView(); m.delegate = context.coordinator; m.showsUserLocation = true
        m.showsTraffic = true; m.showsCompass = false; m.userTrackingMode = .follow; return m
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        guard let target else { return }
        let co = context.coordinator
        guard co.lastTarget.map({ CLLocation(latitude:$0.latitude,longitude:$0.longitude).distance(from:CLLocation(latitude:target.latitude,longitude:target.longitude)) > 5 }) ?? true else { return }
        co.lastTarget = target
        map.removeOverlays(map.overlays); map.removeAnnotations(map.annotations.filter{!($0 is MKUserLocation)})
        let req = MKDirections.Request(); req.transportType = .automobile; req.requestsAlternateRoutes = true
        req.source = origin.map { MKMapItem(placemark: MKPlacemark(coordinate: $0)) } ?? .forCurrentLocation()
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: target))
        MKDirections(request: req).calculate { resp, _ in DispatchQueue.main.async {
            guard let best = resp?.routes.min(by:{$0.expectedTravelTime < $1.expectedTravelTime}) else { return }
            let ff = best.distance/13.9; let r = best.expectedTravelTime/max(ff,1)
            let tl: TrafficLevel = r>2 ? .heavy : r>1.35 ? .moderate : .clear
            let poly = TrafficPolyline(points:best.polyline.points(),count:best.polyline.pointCount,trafficLevel:tl,isAlternate:false)
            map.addOverlay(poly,level:.aboveRoads)
            let mins = Int(best.expectedTravelTime/60); self.eta = mins<=0 ? "< 1 min" : "\(mins) min"
            let km = best.distance/1000; self.distance = km<1 ? "\(Int(best.distance)) m" : String(format:"%.1f km",km)
            self.traffic = tl
        }}
    }
    func makeCoordinator() -> Co { Co() }
    final class Co: NSObject, MKMapViewDelegate {
        var lastTarget: CLLocationCoordinate2D?
        func mapView(_ m: MKMapView, rendererFor o: MKOverlay) -> MKOverlayRenderer {
            guard let p = o as? TrafficPolyline else { return MKOverlayRenderer(overlay:o) }
            let r = MKPolylineRenderer(polyline:p); r.lineCap = .round; r.lineWidth = 5
            switch p.trafficLevel { case .heavy: r.strokeColor=UIColor(red:0.98,green:0.27,blue:0.27,alpha:1); case .moderate: r.strokeColor=UIColor(red:1,green:0.75,blue:0,alpha:1); default: r.strokeColor=UIColor(red:0,green:0.898,blue:0.455,alpha:1) }; return r
        }
    }
}

// MARK: - Shared map helpers
func openInMaps(coord: CLLocationCoordinate2D?, label: String) {
    guard let coord else { return }
    let item = MKMapItem(placemark: MKPlacemark(coordinate: coord)); item.name = label
    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
}

func geocode(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
    CLGeocoder().geocodeAddressString(address + ", South Africa") { placemarks, _ in
        DispatchQueue.main.async { completion(placemarks?.first?.location?.coordinate) }
    }
}

// ECarPin & ESheetHandle shared UI helpers
struct ECarPin: View {
    var body: some View { ZStack { Circle().fill(Color.eGreen.opacity(0.12)).frame(width:34,height:34); Circle().stroke(Color.eGreen.opacity(0.4),lineWidth:1.5).frame(width:34,height:34); Text("🚗").font(.system(size:14)) } }
}
struct ESheetHandle: View {
    var body: some View { RoundedRectangle(cornerRadius:100).fill(Color.eBorder).frame(width:40,height:4).frame(maxWidth:.infinity) }
}
// EErrorBanner defined in Core/Utils/DesignSystem.swift


// Design tokens defined in DesignSystem.swift
