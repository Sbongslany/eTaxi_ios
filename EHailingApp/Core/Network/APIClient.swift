//import Foundation
//
//// MARK: - HTTP Method
//enum HTTPMethod: String { case GET, POST, PUT, DELETE, PATCH }
//
//// MARK: - API Error
//enum APIError: LocalizedError {
//    case invalidURL
//    case noData
//    case decodingFailed(String)
//    case serverError(Int, String)
//    case unauthorized
//    case networkError(String)
//
//    var errorDescription: String? {
//        switch self {
//        case .invalidURL:             return "Invalid URL"
//        case .noData:                 return "No response from server"
//        case .decodingFailed(let m):  return "Data error: \(m)"
//        case .serverError(_, let m):  return m
//        case .unauthorized:           return "Session expired. Please sign in again."
//        case .networkError(let m):    return m
//        }
//    }
//}
//
//// MARK: - JSON Decoder (converts snake_case → camelCase)
//extension JSONDecoder {
//    static let api: JSONDecoder = {
//        let d = JSONDecoder()
//        d.keyDecodingStrategy = .convertFromSnakeCase
//        d.dateDecodingStrategy = .iso8601
//        return d
//    }()
//}
//
//// MARK: - API Client
//final class APIClient {
//    static let shared = APIClient()
//    private let session: URLSession
//
//    private init() {
//        let config = URLSessionConfiguration.default
//        config.timeoutIntervalForRequest  = 30
//        config.timeoutIntervalForResource = 60
//        session = URLSession(configuration: config)
//    }
//
//    // MARK: - JSON Request
//    func request<T: Decodable>(
//        _ endpoint: String,
//        method: HTTPMethod = .GET,
//        body: [String: Any]? = nil,
//        authenticated: Bool = true
//    ) async throws -> T {
//        guard let url = URL(string: Constants.API.baseURL + endpoint) else {
//            throw APIError.invalidURL
//        }
//
//        var req = URLRequest(url: url)
//        req.httpMethod = method.rawValue
//        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//        if authenticated, let token = TokenStore.accessToken {
//            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//        }
//
//        if let body = body {
//            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
//        }
//
//        let (data, response) = try await session.data(for: req)
//        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
//
//        switch http.statusCode {
//        case 200...299:
//            do {
//                return try JSONDecoder.api.decode(T.self, from: data)
//            } catch {
//                let raw = String(data: data, encoding: .utf8) ?? ""
//                throw APIError.decodingFailed("\(error.localizedDescription) — \(raw.prefix(200))")
//            }
//        case 401:
//            TokenStore.clear()
//            throw APIError.unauthorized
//        default:
//            let msg = (try? JSONDecoder.api.decode([String: String].self, from: data))?["message"]
//                ?? "Server error \(http.statusCode)"
//            throw APIError.serverError(http.statusCode, msg)
//        }
//    }
//
//    // MARK: - Multipart Upload
//    func upload(
//        _ endpoint: String,
//        fileData: Data,
//        fileName: String,
//        mimeType: String,
//        fields: [String: String] = [:]
//    ) async throws -> UploadResponse {
//        guard let url = URL(string: Constants.API.baseURL + endpoint) else {
//            throw APIError.invalidURL
//        }
//        let boundary = "Boundary-\(UUID().uuidString)"
//        var req = URLRequest(url: url)
//        req.httpMethod = "POST"
//        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
//        if let token = TokenStore.accessToken {
//            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//        }
//
//        var body = Data()
//        for (key, val) in fields {
//            body.append("--\(boundary)\r\n".data(using: .utf8)!)
//            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
//            body.append("\(val)\r\n".data(using: .utf8)!)
//        }
//        body.append("--\(boundary)\r\n".data(using: .utf8)!)
//        body.append("Content-Disposition: form-data; name=\"document\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
//        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
//        body.append(fileData)
//        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
//        req.httpBody = body
//
//        let (data, response) = try await session.data(for: req)
//        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
//        guard http.statusCode == 200 || http.statusCode == 201 else {
//            let msg = (try? JSONDecoder.api.decode([String: String].self, from: data))?["message"]
//                ?? "Upload failed"
//            throw APIError.serverError(http.statusCode, msg)
//        }
//        return (try? JSONDecoder.api.decode(UploadResponse.self, from: data))
//            ?? UploadResponse(success: true, message: "Uploaded", documentType: nil)
//    }
//}
//
//struct UploadResponse: Decodable {
//    let success: Bool
//    let message: String?
//    let documentType: String?
//}
import Foundation

// MARK: - HTTP Method
enum HTTPMethod: String { case GET, POST, PUT, DELETE, PATCH }

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingFailed(String)
    case serverError(Int, String)
    case unauthorized
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:             return "Invalid URL"
        case .noData:                 return "No response from server"
        case .decodingFailed(let m):  return "Data error: \(m)"
        case .serverError(_, let m):  return m
        case .unauthorized:           return "Session expired. Please sign in again."
        case .networkError(let m):    return m
        }
    }
}

// MARK: - JSON Decoder (converts snake_case → camelCase)
extension JSONDecoder {
    static let api: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

// MARK: - API Client
final class APIClient {
    static let shared = APIClient()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    // MARK: - JSON Request
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        guard let url = URL(string: Constants.API.baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated, let token = TokenStore.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }

        switch http.statusCode {
        case 200...299:
            do {
                return try JSONDecoder.api.decode(T.self, from: data)
            } catch {
                let raw = String(data: data, encoding: .utf8) ?? ""
                throw APIError.decodingFailed("\(error.localizedDescription) — \(raw.prefix(200))")
            }
        case 401:
            TokenStore.clear()
            throw APIError.unauthorized
        default:
            let msg = (try? JSONDecoder.api.decode([String: String].self, from: data))?["message"]
                ?? "Server error \(http.statusCode)"
            throw APIError.serverError(http.statusCode, msg)
        }
    }

    // MARK: - Multipart Upload
    func upload(
        _ endpoint: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fields: [String: String] = [:]
    ) async throws -> UploadResponse {
        guard let url = URL(string: Constants.API.baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = TokenStore.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        for (key, val) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(val)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        guard http.statusCode == 200 || http.statusCode == 201 else {
            let msg = (try? JSONDecoder.api.decode([String: String].self, from: data))?["message"]
                ?? "Upload failed"
            throw APIError.serverError(http.statusCode, msg)
        }
        return (try? JSONDecoder.api.decode(UploadResponse.self, from: data))
            ?? UploadResponse(success: true, message: "Uploaded", documentType: nil)
    }
}

struct UploadResponse: Decodable {
    let success: Bool
    let message: String?
    let documentType: String?
}
