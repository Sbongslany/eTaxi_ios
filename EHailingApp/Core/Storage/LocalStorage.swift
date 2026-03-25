import Foundation

// MARK: - Token Store
final class TokenStore {
    private static let ud = UserDefaults.standard

    static var accessToken: String? {
        get { ud.string(forKey: Constants.Storage.accessToken) }
        set { ud.set(newValue, forKey: Constants.Storage.accessToken) }
    }
    static var refreshToken: String? {
        get { ud.string(forKey: Constants.Storage.refreshToken) }
        set { ud.set(newValue, forKey: Constants.Storage.refreshToken) }
    }
    static var userId: String? {
        get { ud.string(forKey: Constants.Storage.userId) }
        set { ud.set(newValue, forKey: Constants.Storage.userId) }
    }
    static var userRole: String? {
        get { ud.string(forKey: Constants.Storage.userRole) }
        set { ud.set(newValue, forKey: Constants.Storage.userRole) }
    }
    static var isLoggedIn: Bool { accessToken != nil }
    static var isDriver: Bool   { userRole == "driver" }

    static func save(access: String, refresh: String, userId: String, role: String) {
        accessToken      = access
        refreshToken     = refresh
        self.userId      = userId
        userRole         = role
    }

    static func clear() {
        [Constants.Storage.accessToken,
         Constants.Storage.refreshToken,
         Constants.Storage.userId,
         Constants.Storage.userRole,
         Constants.Storage.cachedUser]
            .forEach { ud.removeObject(forKey: $0) }
    }
}

// MARK: - Local Storage (cached user)
final class LocalStorage {
    static let shared = LocalStorage()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private init() {}

    func saveUser(_ user: UserEntity) {
        if let data = try? encoder.encode(user) {
            UserDefaults.standard.set(data, forKey: Constants.Storage.cachedUser)
        }
    }

    func loadUser() -> UserEntity? {
        guard let data = UserDefaults.standard.data(forKey: Constants.Storage.cachedUser) else { return nil }
        return try? decoder.decode(UserEntity.self, from: data)
    }
}
