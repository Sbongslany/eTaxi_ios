import Foundation
import Combine

enum WSEvent {
    case connected
    case driverLocation(lat: Double, lon: Double)
    case tripRequest(tripId: String, pickup: String, dropoff: String, fare: Double, rideType: String)
    case tripStatusChanged(tripId: String, status: String)
    case error(String)
}

final class WebSocketManager: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = WebSocketManager()
    let events = PassthroughSubject<WSEvent, Never>()
    @Published var isConnected = false
    private var task: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectDelay: TimeInterval = 2
    private override init() { super.init() }

    func connect() {
        guard let token = TokenStore.accessToken,
              let url   = URL(string: "\(Constants.API.wsURL)?token=\(token)") else { return }
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        task = session.webSocketTask(with: url)
        task?.resume(); receive(); schedulePing()
    }

    func disconnect() {
        pingTimer?.invalidate(); pingTimer = nil
        task?.cancel(with: .goingAway, reason: nil); task = nil
        isConnected = false
    }

    func subscribeDriver() { send(["type": "SUBSCRIBE_DRIVER"]) }
    func sendLocation(lat: Double, lon: Double) { send(["type": "LOCATION_UPDATE", "lat": lat, "lon": lon]) }
    func declineTrip(_ id: String) { send(["type": "TRIP_DECLINE", "tripId": id]) }

    private func send(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str  = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(str)) { _ in }
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msg): self.handle(msg); self.receive()
            case .failure: DispatchQueue.main.async { self.isConnected = false; self.scheduleReconnect() }
            }
        }
    }

    private func handle(_ msg: URLSessionWebSocketTask.Message) {
        var data: Data?
        switch msg { case .string(let s): data = s.data(using: .utf8); case .data(let d): data = d; @unknown default: return }
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch type {
            case "CONNECTED":
                self.isConnected = true; self.reconnectDelay = 2; self.events.send(.connected)
            case "DRIVER_LOCATION":
                if let lat = json["lat"] as? Double, let lon = json["lon"] as? Double {
                    self.events.send(.driverLocation(lat: lat, lon: lon))
                }
            case "TRIP_REQUEST":
                self.events.send(.tripRequest(
                    tripId:  json["tripId"]         as? String ?? "",
                    pickup:  json["pickupAddress"]  as? String ?? "",
                    dropoff: json["dropoffAddress"] as? String ?? "",
                    fare:    json["estimatedFare"]  as? Double ?? 0,
                    rideType:json["rideType"]       as? String ?? "economy"))
            case "TRIP_UPDATE", "TRIP_STATUS":
                if let tid = json["tripId"] as? String, let st = json["status"] as? String {
                    self.events.send(.tripStatusChanged(tripId: tid, status: st))
                }
            case "ERROR": self.events.send(.error(json["message"] as? String ?? "WS error"))
            default: break
            }
        }
    }

    private func schedulePing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.send(["type": "PING"])
        }
    }
    private func scheduleReconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self else { return }
            self.reconnectDelay = min(self.reconnectDelay * 2, 30)
            self.connect()
        }
    }
}

extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ s: URLSession, webSocketTask t: URLSessionWebSocketTask, didOpenWithProtocol p: String?) {
        DispatchQueue.main.async { self.isConnected = true }
    }
    func urlSession(_ s: URLSession, webSocketTask t: URLSessionWebSocketTask, didCloseWith c: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async { self.isConnected = false; self.scheduleReconnect() }
    }
}
