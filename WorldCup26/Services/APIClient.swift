import Foundation

enum APIError: LocalizedError {
    case notConfigured
    case invalidResponse
    case http(status: Int)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "The match data API is not configured."
        case .invalidResponse: return "The server returned an unexpected response."
        case .http(let status): return "The server responded with status \(status)."
        case .transport(let error): return error.localizedDescription
        case .decoding(let error): return "Could not read the server response: \(error)"
        }
    }
}

/// Thin async/await wrapper over `URLSession` for the Football-Data API.
/// Stateless and `Sendable`; one instance is shared by the repository.
struct APIClient: Sendable {
    let configuration: APIConfiguration
    private let session: URLSession

    init(configuration: APIConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Performs a GET against `path` (relative to the base URL) and decodes the result.
    func get<T: Decodable>(_ type: T.Type, path: String) async throws -> T {
        guard configuration.isConfigured else { throw APIError.notConfigured }

        let url = configuration.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(configuration.apiKey, forHTTPHeaderField: "X-Auth-Token")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(status: http.statusCode) }

        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
