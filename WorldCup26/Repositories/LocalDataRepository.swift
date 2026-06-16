import Foundation

/// Read access to the bundled, offline-first static dataset.
protocol LocalDataRepositoryProtocol {
    func loadTeams() throws -> [Team]
    func loadGroups() throws -> [Group]
    func loadStadiums() throws -> [Stadium]
    func loadMatches() throws -> [Match]
}

/// Loads the static tournament data shipped inside the app bundle.
/// This is the single source of truth when the device is offline.
struct LocalDataRepository: LocalDataRepositoryProtocol {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadTeams() throws -> [Team] {
        try JSONLoader.load([Team].self, from: "teams", bundle: bundle)
    }

    func loadGroups() throws -> [Group] {
        try JSONLoader.load([Group].self, from: "groups", bundle: bundle)
    }

    func loadStadiums() throws -> [Stadium] {
        try JSONLoader.load([Stadium].self, from: "stadiums", bundle: bundle)
    }

    func loadMatches() throws -> [Match] {
        try JSONLoader.load([Match].self, from: "matches", bundle: bundle)
    }
}
