import Foundation

struct AppUser: Equatable {
    let uid: String
    let email: String?
    let displayName: String?
}

enum SupabaseServiceError: LocalizedError {
    case missingConfiguration
    case invalidResponse
    case emailConfirmationRequired
    case decodingFailed
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Supabase is not configured. Add your project URL and anon key to SupabaseConfig.plist."
        case .invalidResponse:
            return "Supabase returned an unexpected response."
        case .emailConfirmationRequired:
            return "Check your email to confirm your account before signing in."
        case .decodingFailed:
            return "Supabase returned account data in an unexpected format. Please try again."
        case .requestFailed(let message):
            return message
        }
    }
}

struct SupabaseAuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let user: SupabaseAuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct SupabaseAuthUser: Decodable {
    let id: String
    let email: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
    }

    enum MetadataKeys: String, CodingKey {
        case displayName = "display_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)

        if let metadata = try? container.nestedContainer(keyedBy: MetadataKeys.self, forKey: .userMetadata) {
            displayName = try metadata.decodeIfPresent(String.self, forKey: .displayName)
        } else {
            displayName = nil
        }
    }
}

final class SupabaseService {
    static let shared = SupabaseService()

    private let keychain = KeychainService.shared
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    private lazy var config: (url: URL, anonKey: String)? = {
        guard let configURL = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: configURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String],
              let urlString = plist["SUPABASE_URL"],
              let anonKey = plist["SUPABASE_ANON_KEY"],
              let url = URL(string: urlString),
              !urlString.contains("YOUR_PROJECT_REF"),
              !anonKey.contains("YOUR_SUPABASE_ANON_KEY") else {
            return nil
        }
        return (url, anonKey)
    }()

    private init() {
        jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
    }

    var currentUser: AppUser? {
        guard let uid = keychain.load(for: KeychainService.supabaseUserId) else { return nil }
        let email = keychain.load(for: KeychainService.supabaseUserEmail)
        return AppUser(uid: uid, email: email, displayName: email?.split(separator: "@").first.map(String.init))
    }

    func login(email: String, password: String) async throws -> AppUser {
        let response: SupabaseAuthResponse = try await authRequest(
            path: "/auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: ["email": email, "password": password]
        )
        return try saveSession(from: response)
    }

    func signup(email: String, password: String) async throws -> AppUser {
        let response: SupabaseAuthResponse = try await authRequest(
            path: "/auth/v1/signup",
            body: ["email": email, "password": password]
        )
        return try saveSession(from: response)
    }

    func logout() async throws {
        defer { clearSession() }
        guard keychain.load(for: KeychainService.supabaseAccessToken) != nil else { return }

        do {
            var request = try makeRequest(path: "/auth/v1/logout", authenticated: true)
            request.httpMethod = "POST"
            request.httpBody = try JSONSerialization.data(withJSONObject: [:])
            _ = try await send(request, allowRefresh: false)
        } catch {
            // Local sign-out should still complete if the session is already expired or offline.
        }
    }

    func select<T: Decodable>(
        table: String,
        queryItems: [URLQueryItem] = [],
        authenticated: Bool = true
    ) async throws -> [T] {
        var items = [URLQueryItem(name: "select", value: "*")]
        items.append(contentsOf: queryItems)
        let request = try makeRequest(path: "/rest/v1/\(table)", queryItems: items, authenticated: authenticated)
        let (data, _) = try await send(request)
        return try jsonDecoder.decode([T].self, from: data)
    }

    func upsert<T: Encodable>(_ value: T, table: String, onConflict: String = "id") async throws {
        var request = try makeRequest(
            path: "/rest/v1/\(table)",
            queryItems: [URLQueryItem(name: "on_conflict", value: onConflict)]
        )
        request.httpMethod = "POST"
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try jsonEncoder.encode(value)
        _ = try await send(request)
    }

    func insert<T: Encodable>(_ value: T, table: String) async throws {
        var request = try makeRequest(path: "/rest/v1/\(table)")
        request.httpMethod = "POST"
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try jsonEncoder.encode(value)
        _ = try await send(request)
    }

    func update<T: Encodable>(_ value: T, table: String, queryItems: [URLQueryItem]) async throws {
        var request = try makeRequest(path: "/rest/v1/\(table)", queryItems: queryItems)
        request.httpMethod = "PATCH"
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try jsonEncoder.encode(value)
        _ = try await send(request)
    }

    func delete(table: String, queryItems: [URLQueryItem]) async throws {
        var request = try makeRequest(path: "/rest/v1/\(table)", queryItems: queryItems)
        request.httpMethod = "DELETE"
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        _ = try await send(request)
    }

    func invokeFunction<RequestBody: Encodable, ResponseBody: Decodable>(
        _ name: String,
        body: RequestBody,
        authenticated: Bool = true
    ) async throws -> ResponseBody {
        var request = try makeRequest(path: "/functions/v1/\(name)", authenticated: authenticated)
        request.httpMethod = "POST"
        request.httpBody = try jsonEncoder.encode(body)
        let (data, _) = try await send(request)
        return try jsonDecoder.decode(ResponseBody.self, from: data)
    }

    private func authRequest<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        body: [String: String]
    ) async throws -> T {
        var request = try makeRequest(path: path, queryItems: queryItems, authenticated: false)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await send(request)
        if T.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! T
        }
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw SupabaseServiceError.decodingFailed
        }
    }

    private func makeRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        authenticated: Bool = true
    ) throws -> URLRequest {
        guard let config else { throw SupabaseServiceError.missingConfiguration }
        guard var components = URLComponents(url: config.url, resolvingAgainstBaseURL: false) else {
            throw SupabaseServiceError.invalidResponse
        }
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw SupabaseServiceError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated, let token = keychain.load(for: KeychainService.supabaseAccessToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send(_ request: URLRequest, allowRefresh: Bool = true) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseServiceError.invalidResponse }
        if http.statusCode == 401,
           allowRefresh,
           request.value(forHTTPHeaderField: "Authorization") == "Bearer \(keychain.load(for: KeychainService.supabaseAccessToken) ?? "")" {
            try await refreshAccessToken()
            var retry = request
            if let token = keychain.load(for: KeychainService.supabaseAccessToken) {
                retry.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            return try await send(retry, allowRefresh: false)
        }
        guard 200..<300 ~= http.statusCode else {
            let message = (try? jsonDecoder.decode(SupabaseErrorResponse.self, from: data).displayMessage)
                ?? String(data: data, encoding: .utf8)
                ?? "Supabase request failed."
            throw SupabaseServiceError.requestFailed(message)
        }
        return (data, http)
    }

    private func refreshAccessToken() async throws {
        guard let refreshToken = keychain.load(for: KeychainService.supabaseRefreshToken) else {
            throw SupabaseServiceError.requestFailed("Session expired. Please sign in again.")
        }
        let response: SupabaseAuthResponse = try await authRequest(
            path: "/auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: ["refresh_token": refreshToken]
        )
        _ = try saveSession(from: response)
    }

    private func saveSession(from response: SupabaseAuthResponse) throws -> AppUser {
        guard let user = response.user else { throw SupabaseServiceError.invalidResponse }
        guard let accessToken = response.accessToken else {
            throw SupabaseServiceError.emailConfirmationRequired
        }
        _ = keychain.save(accessToken, for: KeychainService.supabaseAccessToken)
        if let refreshToken = response.refreshToken {
            _ = keychain.save(refreshToken, for: KeychainService.supabaseRefreshToken)
        }
        _ = keychain.save(user.id, for: KeychainService.supabaseUserId)
        if let email = user.email {
            _ = keychain.save(email, for: KeychainService.supabaseUserEmail)
        }
        return AppUser(uid: user.id, email: user.email, displayName: user.displayName ?? user.email?.split(separator: "@").first.map(String.init))
    }

    private func clearSession() {
        keychain.delete(for: KeychainService.supabaseAccessToken)
        keychain.delete(for: KeychainService.supabaseRefreshToken)
        keychain.delete(for: KeychainService.supabaseUserId)
        keychain.delete(for: KeychainService.supabaseUserEmail)
    }
}

private struct SupabaseErrorResponse: Decodable {
    let message: String?
    let msg: String?
    let errorDescription: String?

    var displayMessage: String? {
        message ?? msg ?? errorDescription
    }

    enum CodingKeys: String, CodingKey {
        case message
        case msg
        case errorDescription = "error_description"
    }
}

private struct EmptyResponse: Decodable {}
