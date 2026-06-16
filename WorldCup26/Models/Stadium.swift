import Foundation

/// A host venue. Loaded from bundled JSON.
struct Stadium: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let city: String
    let country: String
    let capacity: Int?

    var location: String { "\(city), \(country)" }
}
