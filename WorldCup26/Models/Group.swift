import Foundation

/// A first-round group (A–L). Loaded from bundled JSON.
struct Group: Codable, Identifiable, Hashable {
    /// Group letter, e.g. "A".
    let id: String
    let name: String
    /// Team ids belonging to this group, in seeding order.
    let teamIds: [String]
}
