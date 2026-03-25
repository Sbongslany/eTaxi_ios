import Foundation

enum Constants {
    enum API {
        static let baseURL = "http://192.168.0.181:5001/api/v1"
        static let wsURL   = "ws://192.168.0.181:5001/ws"
    }

    enum Storage {
        static let accessToken  = "etaxi_access_token"
        static let refreshToken = "etaxi_refresh_token"
        static let userId       = "etaxi_user_id"
        static let userRole     = "etaxi_user_role"
        static let cachedUser   = "etaxi_cached_user"
    }

    enum Auth {
        static let otpLength    = 6
        static let minPassword  = 8
    }
}
