import Foundation

/// Decodes bundled JSON resources. Centralises decoder configuration so every
/// model decodes dates and keys identically.
enum JSONLoader {
    enum LoaderError: LocalizedError {
        case missingResource(String)
        case decodingFailed(String, underlying: Error)

        var errorDescription: String? {
            switch self {
            case .missingResource(let name):
                return "Bundled resource '\(name).json' was not found."
            case .decodingFailed(let name, let underlying):
                return "Failed to decode '\(name).json': \(underlying)"
            }
        }
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Loads and decodes `<name>.json` from the given bundle.
    static func load<T: Decodable>(_ type: T.Type, from name: String, bundle: Bundle = .main) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw LoaderError.missingResource(name)
        }
        let data = try Data(contentsOf: url)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw LoaderError.decodingFailed(name, underlying: error)
        }
    }
}
