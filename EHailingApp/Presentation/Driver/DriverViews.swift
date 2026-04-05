import SwiftUI
import MapKit

// MARK: - Driver Root
struct DriverRoot: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm: DriverViewModel
    init(user: UserEntity) { _vm = StateObject(wrappedValue: DriverViewModel(user: user)) }
    var body: some View {
        ZStack {
            Group {
                switch vm.screen {
                case .home:        DHomeView(vm: vm)
                case .enRoute:     DEnRouteView(vm: vm)
                case .arrived:     DArrivedView(vm: vm)
                case .activeTrip:  DActiveTripView(vm: vm)
                case .tripComplete:DTripCompleteView(vm: vm)
                case .trips:       DTripsView(vm: vm)
                case .earnings:    DEarningsView(vm: vm)
                case .profile:     DProfileView(vm: vm)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: vm.screen)

            // Trip request overlay
            if vm.hasPending, let req = vm.pendingRequest {
                DTripRequestOverlay(vm: vm, req: req)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                    .animation(.spring(response: 0.4), value: vm.hasPending)
            }
        }
    }
}

// MARK: - Driver Home Map
struct DHomeView: View {
    @ObservedObject var vm: DriverViewModel
    @StateObject private var locMgr = LocationManager.shared


    var body: some View {
        ZStack(alignment: .bottom) {
            EHomeMap(nearbyPins: []).ignoresSafeArea()

            VStack {
                // Top bar
                VStack(spacing: 0) {
                    Color.clear.frame(height: 10)
                    HStack {
                        HStack(spacing: 0) {
                            Text("e").font(EFont.display(20, weight: .heavy)).foregroundColor(.eText)
                            Text("Taxi").font(EFont.display(20, weight: .heavy)).foregroundColor(.eAccent)
                        }
                        Spacer()
                        // Online indicator
                        HStack(spacing: 8) {
                            Circle().fill(vm.isOnline ? Color.eGreen : Color.eTextMuted).frame(width: 8, height: 8)
                            Text(vm.isOnline ? "Online" : "Offline").font(EFont.body(13, weight: .bold)).foregroundColor(vm.isOnline ? .eGreen : .eTextMuted)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8).background(Color.eCard.opacity(0.92)).clipShape(Capsule())
                        .overlay(Capsule().stroke((vm.isOnline ? Color.eGreen : Color.eBorder).opacity(0.4), lineWidth: 1))
                    }.padding(.horizontal, 20).padding(.vertical, 12)
                }
                .background(LinearGradient(colors: [Color.eBackground.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom))
                Spacer()
            }

            // Bottom sheet
            VStack(alignment: .leading, spacing: 0) {
                ESheetHandle().padding(.top, 12).padding(.bottom, 16)
                // Online / Offline toggle
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.isOnline ? "You're Online" : "You're Offline")
                            .font(EFont.display(20, weight: .heavy)).foregroundColor(.eText)
                        Text(vm.isOnline ? "Waiting for ride requests…" : "Go online to receive trips")
                            .font(EFont.body(14)).foregroundColor(.eTextSoft)
                    }
                    Spacer()
                    Button {
                        if vm.isOnline { vm.goOffline() } else { vm.goOnline() }
                    } label: {
                        ZStack {
                            Capsule().fill(vm.isOnline ? Color.eGreen : Color.eSurface2)
                                .frame(width: 56, height: 32)
                                .overlay(Capsule().stroke(vm.isOnline ? Color.clear : Color.eBorder, lineWidth: 1.5))
                            Circle().fill(Color.white).frame(width: 24, height: 24)
                                .offset(x: vm.isOnline ? 12 : -12)
                                .animation(.spring(response: 0.35), value: vm.isOnline)
                        }
                    }.disabled(vm.isLoading)
                }
                .padding(16).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.bottom, 16)

                // Stats
                if let p = vm.profile {
                    HStack(spacing: 12) {
                        dStat(label: "Total Trips", value: "\(p.totalTrips)")
                        dStat(label: "Earnings", value: "R\(Int(p.totalEarnings))")
                        dStat(label: "Acceptance", value: "\(Int(p.acceptanceRate * 100))%")
                    }.padding(.bottom, 16)
                }

                if let err = vm.errorMessage { EErrorBanner(message: err).padding(.bottom, 12) }
            }
            .padding(.horizontal, 20).padding(.bottom, 100)
            .background(Color.eCard).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.eBorder, lineWidth: 1) }
            .safeAreaInset(edge: .bottom) { DTabBar(vm: vm) }
        }
        .ignoresSafeArea()
        .onAppear { locMgr.start() }

    }

    @ViewBuilder private func dStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(EFont.display(20, weight: .heavy)).foregroundColor(.eText)
            Text(label).font(EFont.body(11)).foregroundColor(.eTextMuted)
        }.frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct DTabBar: View {
    @ObservedObject var vm: DriverViewModel
    let tabs: [(String, String, DScreen)] = [("map.fill","Map",.home),("clock.fill","Trips",.trips),("chart.bar.fill","Earnings",.earnings),("person.fill","Profile",.profile)]
    var body: some View {
        HStack {
            ForEach(tabs, id: \.1) { icon, label, target in
                Button { vm.screen = target; if target == .trips { Task { await vm.loadHistory() } }; if target == .earnings { Task { await vm.loadEarnings() } } } label: {
                    let sel = vm.screen == target
                    VStack(spacing: 4) {
                        Image(systemName: sel ? icon : icon.replacingOccurrences(of: ".fill", with: "")).font(.system(size: 20)).foregroundColor(sel ? .eAccent : .eTextMuted)
                        Text(label).font(EFont.body(10, weight: sel ? .bold : .regular)).foregroundColor(sel ? .eAccent : .eTextMuted)
                    }.frame(maxWidth: .infinity)
                }
            }
        }.padding(.horizontal, 20).padding(.vertical, 12).background(Color.eCard).overlay(alignment: .top) { Rectangle().fill(Color.eBorder).frame(height: 0.5) }
    }
}

// MARK: - Trip Request Overlay
struct DTripRequestOverlay: View {
    @ObservedObject var vm: DriverViewModel
    let req: TripRequestItem
    @State private var timeLeft = 30; @State private var timer: Timer?
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                ESheetHandle().padding(.top, 12).padding(.bottom, 16)
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.eAccent.opacity(0.15)).frame(width: 52, height: 52)
                            Text(req.isCustom ? "📅" : "⚡️").font(.system(size: 28))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(req.isCustom ? "Custom Hire Request" : "Standard Ride Request").font(EFont.body(13, weight: .bold)).foregroundColor(.eTextMuted)
                            Text("R\(Int(req.fare))").font(EFont.display(28, weight: .heavy)).foregroundColor(.eText)
                        }
                        Spacer()
                        ZStack {
                            Circle().stroke(Color.eBorder, lineWidth: 3).frame(width: 48, height: 48)
                            Circle().trim(from: 0, to: CGFloat(timeLeft) / 30).stroke(Color.eGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round)).frame(width: 48, height: 48).rotationEffect(.degrees(-90)).animation(.linear(duration: 1), value: timeLeft)
                            Text("\(timeLeft)").font(EFont.mono(14)).foregroundColor(.eText)
                        }
                    }

                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Circle().fill(Color.eGreen).frame(width: 10, height: 10)
                            Text(req.pickup).font(EFont.body(14)).foregroundColor(.eText).lineLimit(1); Spacer()
                        }
                        HStack(spacing: 12) {
                            Circle().fill(Color.eAccent).frame(width: 10, height: 10)
                            Text(req.dropoff).font(EFont.body(14)).foregroundColor(.eText).lineLimit(1); Spacer()
                        }
                    }.padding(14).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 14))

                    HStack(spacing: 12) {
                        Button { vm.declineTrip() } label: {
                            Text("Decline").font(EFont.body(16, weight: .bold)).foregroundColor(.eRed)
                                .frame(maxWidth: .infinity).frame(height: 52).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.eRed.opacity(0.4), lineWidth: 1.5))
                        }
                        Button { vm.acceptTrip() } label: {
                            Text("Accept").font(EFont.body(16, weight: .bold)).foregroundColor(.black)
                                .frame(maxWidth: .infinity).frame(height: 52).background(Color.eGreen).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }.padding(.horizontal, 20).padding(.bottom, 36)
            }
            .background(Color.eCard).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .ignoresSafeArea()
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in
                    if timeLeft > 0 { timeLeft -= 1 } else { timer?.invalidate(); vm.declineTrip() }
                }
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}

// MARK: - Driver En Route (driver → pickup)
struct DEnRouteView: View {
    @ObservedObject var vm: DriverViewModel
    var body: some View {
        ZStack(alignment: .bottom) {
            ETaxiMap(origin: vm.driverCoord, target: vm.currentTrip?.pickupCoord,
                     isPickup: true, fitRoute: false,
                     eta: $vm.mapEta, distance: $vm.mapDist, traffic: $vm.mapTraffic)
                .ignoresSafeArea()
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("En Route to Pickup").font(EFont.body(13, weight: .bold)).foregroundColor(.eTextMuted)
                        Text(vm.mapEta).font(EFont.display(32, weight: .heavy)).foregroundColor(.eGreen)
                    }.padding(.horizontal, 14).padding(.vertical, 10).background(Color.eCard.opacity(0.95)).clipShape(RoundedRectangle(cornerRadius: 14))
                    Spacer()
                }.padding(.horizontal, 16).padding(.top, 54)
                if vm.mapTraffic == .heavy {
                    HStack(spacing: 8) { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.eAccent); Text("Heavy traffic").font(EFont.body(13, weight: .semibold)).foregroundColor(.eText) }
                        .padding(.horizontal, 14).padding(.vertical, 8).background(Color.eAccent.opacity(0.15)).clipShape(Capsule()).padding(.top, 8).padding(.leading, 16)
                }
                Spacer()
            }
            VStack(spacing: 14) {
                ESheetHandle().padding(.top, 12)
                if let trip = vm.currentTrip {
                    HStack(spacing: 14) {
                        ZStack { Circle().fill(Color.eGreen.opacity(0.15)).frame(width: 48, height: 48); Text("🧑").font(.system(size: 24)) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(trip.pickupAddress).font(EFont.body(15, weight: .bold)).foregroundColor(.eText).lineLimit(1)
                            Text("Picking up passenger").font(EFont.body(12)).foregroundColor(.eTextSoft)
                        }
                        Spacer()
                        Button { openInMaps(coord: trip.pickupCoord, label: "Pickup") } label: {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill").font(.system(size: 18)).foregroundColor(.eGreen)
                                .frame(width: 44, height: 44).background(Color.eGreen.opacity(0.12)).clipShape(Circle())
                        }
                    }.padding(16).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                EPrimaryButton(title: "I've Arrived") { vm.markArrived() }
            }.padding(.horizontal, 20).padding(.bottom, 36)
            .background(Color.eCard).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }.ignoresSafeArea()
    }
}

// MARK: - Driver Arrived at Pickup
struct DArrivedView: View {
    @ObservedObject var vm: DriverViewModel
    var body: some View {
        ZStack(alignment: .bottom) {
            ETaxiMap(origin: vm.driverCoord, target: vm.currentTrip?.pickupCoord,
                     isPickup: true, fitRoute: false,
                     eta: $vm.mapEta, distance: $vm.mapDist, traffic: $vm.mapTraffic)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ESheetHandle().padding(.top, 12)
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 28)).foregroundColor(.eGreen)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("You've Arrived!").font(EFont.display(20, weight: .heavy)).foregroundColor(.eText)
                        Text("Waiting for passenger…").font(EFont.body(14)).foregroundColor(.eTextSoft)
                    }
                    Spacer()
                }.padding(16).background(Color.eGreen.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 16))

                if let trip = vm.currentTrip {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) { Circle().fill(Color.eGreen).frame(width: 10, height: 10); Text(trip.pickupAddress).font(EFont.body(14)).foregroundColor(.eText).lineLimit(1); Spacer() }.padding(.vertical, 10)
                        Rectangle().fill(Color.eBorder).frame(width: 1, height: 14).padding(.leading, 6)
                        HStack(spacing: 12) { Circle().fill(Color.eAccent).frame(width: 10, height: 10); Text(trip.dropoffAddress).font(EFont.body(14)).foregroundColor(.eText).lineLimit(1); Spacer() }.padding(.vertical, 10)
                    }.padding(14).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 14))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) { Text("Estimated Fare").font(EFont.body(12)).foregroundColor(.eTextMuted); Text(trip.fareStr).font(EFont.display(24, weight: .heavy)).foregroundColor(.eText) }
                        Spacer()
                        if let km = trip.estimatedDistanceKm { VStack(alignment: .trailing, spacing: 2) { Text("Distance").font(EFont.body(12)).foregroundColor(.eTextMuted); Text(String(format: "%.1f km", km)).font(EFont.display(18, weight: .bold)).foregroundColor(.eTextSoft) } }
                    }.padding(16).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 16))
                }

                HStack(spacing: 12) {
                    Button {} label: { VStack(spacing: 5) { Image(systemName: "phone.fill").font(.system(size: 18)).foregroundColor(.eText); Text("Call").font(EFont.body(12, weight: .semibold)).foregroundColor(.eText) }.frame(maxWidth: .infinity).frame(height: 56).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 14)) }
                    EPrimaryButton(title: "Start Ride") { vm.startRide() }
                }
            }.padding(.horizontal, 20).padding(.bottom, 36)
            .background(Color.eCard).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }.ignoresSafeArea()
    }
}

// MARK: - Driver Active Trip (in progress → dropoff)
struct DActiveTripView: View {
    @ObservedObject var vm: DriverViewModel
    @State private var showComplete = false
    var body: some View {
        ZStack(alignment: .bottom) {
            ETaxiMap(origin: vm.driverCoord, target: vm.currentTrip?.dropoffCoord,
                     isPickup: false, fitRoute: false,
                     eta: $vm.mapEta, distance: $vm.mapDist, traffic: $vm.mapTraffic)
                .ignoresSafeArea()
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To Dropoff").font(EFont.body(13, weight: .bold)).foregroundColor(.eTextMuted)
                        Text(vm.mapEta).font(EFont.display(32, weight: .heavy)).foregroundColor(.eAccent)
                    }.padding(.horizontal, 14).padding(.vertical, 10).background(Color.eCard.opacity(0.95)).clipShape(RoundedRectangle(cornerRadius: 14))
                    Spacer()
                    if vm.mapTraffic == .heavy {
                        HStack(spacing: 6) { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.eAccent); Text("Traffic").font(EFont.body(12, weight: .bold)).foregroundColor(.eAccent) }
                            .padding(.horizontal, 12).padding(.vertical, 8).background(Color.eAccent.opacity(0.15)).clipShape(Capsule())
                    }
                }.padding(.horizontal, 16).padding(.top, 54); Spacer()
            }
            VStack(spacing: 14) {
                ESheetHandle().padding(.top, 12)
                if let trip = vm.currentTrip {
                    HStack(spacing: 14) {
                        ZStack { Circle().fill(Color.eAccent.opacity(0.15)).frame(width: 48, height: 48); Image(systemName: "flag.checkered").font(.system(size: 22)).foregroundColor(.eAccent) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(trip.dropoffAddress).font(EFont.body(15, weight: .bold)).foregroundColor(.eText).lineLimit(1)
                            Text(vm.mapDist + " away").font(EFont.body(12)).foregroundColor(.eTextSoft)
                        }
                        Spacer()
                        Button { openInMaps(coord: trip.dropoffCoord, label: "Drop-off") } label: {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill").font(.system(size: 18)).foregroundColor(.eAccent)
                                .frame(width: 44, height: 44).background(Color.eAccent.opacity(0.12)).clipShape(Circle())
                        }
                    }.padding(16).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 16))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) { Text("Trip Fare").font(EFont.body(12)).foregroundColor(.eTextMuted); Text(trip.fareStr).font(EFont.display(24, weight: .heavy)).foregroundColor(.eText) }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) { Text("ETA").font(EFont.body(12)).foregroundColor(.eTextMuted); Text(vm.mapEta).font(EFont.display(18, weight: .bold)).foregroundColor(.eAccent) }
                    }.padding(16).background(Color.eSurface2).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                EPrimaryButton(title: "Complete Trip") { showComplete = true }
            }.padding(.horizontal, 20).padding(.bottom, 36)
            .background(Color.eCard).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .ignoresSafeArea()
        .alert("Complete Trip?", isPresented: $showComplete) { Button("Complete", role: .destructive) { vm.completeRide() }; Button("Cancel", role: .cancel) {} }
        message: { Text("Confirm you've dropped off the passenger at the destination.") }
    }
}

// MARK: - Driver Trip Complete
struct DTripCompleteView: View {
    @ObservedObject var vm: DriverViewModel
    @State private var appeared = false
    var body: some View {
        ZStack { Color.eBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle().fill(Color.eAccent.opacity(0.12)).frame(width: 120, height: 120).scaleEffect(appeared ? 1 : 0.5)
                    Image(systemName: "checkmark").font(.system(size: 44, weight: .bold)).foregroundColor(.eAccent).scaleEffect(appeared ? 1 : 0)
                }.animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)
                Text("Trip Complete! 🎉").font(EFont.display(28, weight: .heavy)).foregroundColor(.eText)
                if let trip = vm.currentTrip {
                    VStack(spacing: 8) {
                        Text("You Earned").font(EFont.body(16)).foregroundColor(.eTextSoft)
                        Text(trip.fareStr).font(.system(size: 52, weight: .black, design: .rounded)).foregroundColor(.eAccent)
                    }
                    VStack(spacing: 0) {
                        tcDRow(icon: "location.fill",   color: .eGreen,    label: "Pickup",  val: trip.pickupAddress)
                        Divider().background(Color.eBorder).padding(.leading, 54)
                        tcDRow(icon: "flag.checkered", color: .eAccent,   label: "Dropoff", val: trip.dropoffAddress)
                        if let km = trip.estimatedDistanceKm { Divider().background(Color.eBorder).padding(.leading, 54); tcDRow(icon: "road.lanes", color: .eTextSoft, label: "Distance", val: String(format: "%.1f km", km)) }
                    }.background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 24)
                }
                EPrimaryButton(title: "Back to Home") { vm.dismissTripComplete() }.padding(.horizontal, 24)
                Spacer()
            }
        }.onAppear { withAnimation { appeared = true } }
    }
    @ViewBuilder private func tcDRow(icon: String, color: Color, label: String, val: String) -> some View {
        HStack(spacing: 14) {
            ZStack { RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)).frame(width: 36, height: 36); Image(systemName: icon).font(.system(size: 14)).foregroundColor(color) }
            VStack(alignment: .leading, spacing: 2) { Text(label).font(EFont.body(11)).foregroundColor(.eTextMuted); Text(val).font(EFont.body(14, weight: .semibold)).foregroundColor(.eText).lineLimit(1) }
            Spacer()
        }.padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - Driver Trips History
struct DTripsView: View {
    @ObservedObject var vm: DriverViewModel
    var body: some View {
        ZStack { Color.eBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { vm.screen = .home } label: { Image(systemName: "arrow.left").font(.system(size: 16, weight: .semibold)).foregroundColor(.eText).frame(width: 38, height: 38).background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 10)) }
                    Text("My Trips").font(EFont.display(22, weight: .heavy)).foregroundColor(.eText); Spacer()
                }.padding(.horizontal, 20).padding(.top, 54).padding(.bottom, 16)
                if vm.tripHistory.isEmpty {
                    Spacer(); VStack(spacing: 16) { Image(systemName: "car.fill").font(.system(size: 48)).foregroundColor(.eTextMuted); Text("No trips yet").font(EFont.display(20, weight: .heavy)).foregroundColor(.eText) }; Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) { ForEach(vm.tripHistory) { dtCard($0) } }.padding(.horizontal, 20).padding(.bottom, 40)
                    }
                }
            }
        }.task { await vm.loadHistory() }
    }
    @ViewBuilder private func dtCard(_ trip: BETrip) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) { Text(trip.rideType.capitalized).font(EFont.body(11, weight: .bold)).foregroundColor(.eTextMuted).kerning(0.5); Text(trip.pickupAddress).font(EFont.body(14, weight: .semibold)).foregroundColor(.eText).lineLimit(1) }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) { Text(trip.fareStr).font(EFont.display(18, weight: .heavy)).foregroundColor(.eAccent); Text(trip.statusLabel).font(EFont.body(11, weight: .bold)).foregroundColor(trip.status == "completed" ? .eGreen : .eRed) }
            }.padding(.horizontal, 16).padding(.top, 16)
            Divider().background(Color.eBorder).padding(.horizontal, 16).padding(.vertical, 10)
            HStack(spacing: 10) { Image(systemName: "mappin").font(.system(size: 12)).foregroundColor(.eTextMuted); Text(trip.dropoffAddress).font(EFont.body(13)).foregroundColor(.eTextSoft).lineLimit(1); Spacer() }.padding(.horizontal, 16).padding(.bottom, 16)
        }.background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.eBorder, lineWidth: 1))
    }
}

// MARK: - Driver Earnings
struct DEarningsView: View {
    @ObservedObject var vm: DriverViewModel
    var body: some View {
        ZStack { Color.eBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack { Button { vm.screen = .home } label: { Image(systemName: "arrow.left").font(.system(size: 16, weight: .semibold)).foregroundColor(.eText).frame(width: 38, height: 38).background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 10)) }; Text("Earnings").font(EFont.display(22, weight: .heavy)).foregroundColor(.eText); Spacer() }.padding(.horizontal, 20).padding(.top, 54).padding(.bottom, 24)
                if let e = vm.earnings {
                    VStack(spacing: 16) {
                        VStack(spacing: 8) { Text("Today").font(EFont.body(14)).foregroundColor(.eTextSoft); Text(e.today ?? "R0").font(.system(size: 52, weight: .black, design: .rounded)).foregroundColor(.eAccent) }.frame(maxWidth: .infinity).padding(24).background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 20)
                        HStack(spacing: 12) {
                            deRow(label: "This Week", val: e.week ?? "R0")
                            deRow(label: "Total Trips", val: "\(e.totalTrips ?? 0)")
                        }.padding(.horizontal, 20)
                    }
                } else {
                    Spacer(); ProgressView().tint(.eAccent); Spacer()
                }
                Spacer()
            }
        }.task { await vm.loadEarnings() }
    }
    @ViewBuilder private func deRow(label: String, val: String) -> some View {
        VStack(spacing: 4) { Text(val).font(EFont.display(22, weight: .heavy)).foregroundColor(.eText); Text(label).font(EFont.body(12)).foregroundColor(.eTextMuted) }.frame(maxWidth: .infinity).padding(20).background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Driver Profile
struct DProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var vm: DriverViewModel
    var body: some View {
        ZStack { Color.eBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack { Button { vm.screen = .home } label: { Image(systemName: "arrow.left").font(.system(size: 16, weight: .semibold)).foregroundColor(.eText).frame(width: 38, height: 38).background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 10)) }; Text("Profile").font(EFont.display(22, weight: .heavy)).foregroundColor(.eText); Spacer() }.padding(.horizontal, 20).padding(.top, 54).padding(.bottom, 28)
                    ZStack { Circle().fill(Color.eAccent.opacity(0.2)).frame(width: 88, height: 88); Text(vm.user.initials).font(EFont.display(32, weight: .heavy)).foregroundColor(.eAccent) }.padding(.bottom, 16)
                    Text(vm.user.fullName).font(EFont.display(22, weight: .heavy)).foregroundColor(.eText)
                    if let code = vm.profile?.driverCode { Text("Driver Code: \(code)").font(EFont.body(14, weight: .bold)).foregroundColor(.eAccent).padding(.top, 4) }
                    if let vehicle = vm.profile?.vehicleDisplay, !vehicle.isEmpty { Text(vehicle).font(EFont.body(14)).foregroundColor(.eTextSoft).padding(.top, 2) }
                    VStack(spacing: 0) {
                        dpRow(icon: "clock", label: "Trip History") { vm.screen = .trips; Task { await vm.loadHistory() } }
                        Divider().background(Color.eBorder).padding(.leading, 54)
                        dpRow(icon: "chart.bar", label: "Earnings") { vm.screen = .earnings; Task { await vm.loadEarnings() } }
                        Divider().background(Color.eBorder).padding(.leading, 54)
                        dpRow(icon: "questionmark.circle", label: "Help & Support") {}
                    }.background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 20).padding(.top, 28)
                    Button { authVM.logout() } label: {
                        HStack { Image(systemName: "rectangle.portrait.and.arrow.right"); Text("Sign Out") }.font(EFont.body(15, weight: .semibold)).foregroundColor(.eRed).frame(maxWidth: .infinity).frame(height: 52).background(Color.eSurface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.eBorder, lineWidth: 1))
                    }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 40)
                }
            }
        }
    }
    @ViewBuilder private func dpRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 16) { Image(systemName: icon).font(.system(size: 18)).foregroundColor(.eTextSoft).frame(width: 24); Text(label).font(EFont.body(15)).foregroundColor(.eText); Spacer(); Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(.eTextMuted) }.padding(.horizontal, 16).padding(.vertical, 16) }
    }
}

// MARK: - Open in Apple Maps
func openInMaps(coord: CLLocationCoordinate2D?, label: String) {
    guard let coord else { return }
    let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
    item.name = label
    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
}
