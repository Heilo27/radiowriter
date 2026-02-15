import Foundation

/// Service for managing DMR ID database from RadioID.net.
/// Provides offline lookup of callsigns and DMR IDs for amateur radio operators.
@MainActor
final class DMRIDService: ObservableObject {
    /// Shared instance for app-wide use.
    static let shared = DMRIDService()

    /// A DMR ID record from the database.
    struct DMRRecord: Codable, Identifiable, Hashable, Sendable {
        let id: UInt32  // DMR ID
        let callsign: String
        let name: String
        let city: String
        let state: String
        let country: String

        enum CodingKeys: String, CodingKey {
            case id = "radio_id"
            case callsign
            case name = "fname"
            case city
            case state
            case country
        }

        /// Full name with callsign for display.
        var displayName: String {
            if name.isEmpty {
                return callsign
            }
            return "\(name) (\(callsign))"
        }

        /// Location string for display.
        var location: String {
            [city, state, country].filter { !$0.isEmpty }.joined(separator: ", ")
        }
    }

    /// Database loading state.
    enum LoadingState {
        case idle
        case loading(progress: Double)
        case loaded(count: Int)
        case error(String)
    }

    /// Current loading state.
    @Published var state: LoadingState = .idle

    /// Last database update time.
    @Published var lastUpdated: Date?

    /// Number of records in the database.
    @Published var recordCount: Int = 0

    /// In-memory index for fast lookups.
    private var recordsByID: [UInt32: DMRRecord] = [:]
    private var recordsByCallsign: [String: DMRRecord] = [:]

    /// Path to the cached database file.
    private var databaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("MotorolaCPS", isDirectory: true)
        return appFolder.appendingPathComponent("dmrid-database.json")
    }

    /// Path to metadata file.
    private var metadataURL: URL {
        databaseURL.deletingLastPathComponent().appendingPathComponent("dmrid-metadata.json")
    }

    private init() {
        loadCachedDatabase()
    }

    // MARK: - Public API

    /// Looks up a DMR record by ID.
    /// - Parameter id: The DMR ID to look up
    /// - Returns: The record if found, nil otherwise
    func lookup(byID id: UInt32) -> DMRRecord? {
        recordsByID[id]
    }

    /// Looks up a DMR record by callsign.
    /// - Parameter callsign: The callsign to look up (case-insensitive)
    /// - Returns: The record if found, nil otherwise
    func lookup(byCallsign callsign: String) -> DMRRecord? {
        recordsByCallsign[callsign.uppercased()]
    }

    /// Searches for records matching a query string.
    /// - Parameters:
    ///   - query: Search query (matches callsign, name, or DMR ID)
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of matching records
    func search(_ query: String, limit: Int = 20) -> [DMRRecord] {
        guard !query.isEmpty else { return [] }

        let lowercased = query.lowercased()
        var results: [DMRRecord] = []

        // First, check for exact ID match
        if let id = UInt32(query), let record = recordsByID[id] {
            results.append(record)
        }

        // Then search callsigns (prefix match)
        let uppercased = query.uppercased()
        for (callsign, record) in recordsByCallsign {
            if callsign.hasPrefix(uppercased) && !results.contains(where: { $0.id == record.id }) {
                results.append(record)
                if results.count >= limit { return results }
            }
        }

        // Finally search names
        for record in recordsByID.values {
            if record.name.lowercased().contains(lowercased) &&
               !results.contains(where: { $0.id == record.id }) {
                results.append(record)
                if results.count >= limit { return results }
            }
        }

        return results
    }

    /// Downloads the latest database from RadioID.net.
    /// - Parameter forceRefresh: If true, downloads even if cache is recent
    func downloadDatabase(forceRefresh: Bool = false) async {
        // Check if we need to refresh (cache for 7 days unless forced)
        if !forceRefresh, let lastUpdate = lastUpdated,
           Date().timeIntervalSince(lastUpdate) < 7 * 24 * 60 * 60 {
            return
        }

        state = .loading(progress: 0)

        do {
            // RadioID.net provides a JSON API for user data
            // Note: This uses the public API endpoint
            let url = URL(string: "https://radioid.net/api/dmr/user/?country=United%20States")!

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                state = .error("Failed to download database")
                return
            }

            state = .loading(progress: 0.5)

            // Parse the JSON response
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(RadioIDAPIResponse.self, from: data)

            state = .loading(progress: 0.7)

            // Save to cache
            try saveDatabase(apiResponse.results)

            // Load into memory
            loadRecords(apiResponse.results)

            // Save metadata
            saveMetadata()

            state = .loaded(count: recordCount)

        } catch {
            state = .error("Download failed: \(error.localizedDescription)")
        }
    }

    /// Clears the local database cache.
    func clearCache() {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(at: metadataURL)
        recordsByID.removeAll()
        recordsByCallsign.removeAll()
        recordCount = 0
        lastUpdated = nil
        state = .idle
    }

    // MARK: - Private Methods

    private func loadCachedDatabase() {
        // Load metadata
        if let data = try? Data(contentsOf: metadataURL),
           let metadata = try? JSONDecoder().decode(DatabaseMetadata.self, from: data) {
            lastUpdated = metadata.lastUpdated
        }

        // Load database
        let dbURL = databaseURL  // Capture before async closure
        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            state = .idle
            return
        }

        state = .loading(progress: 0)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let data = try Data(contentsOf: dbURL)
                let records = try JSONDecoder().decode([DMRRecord].self, from: data)

                DispatchQueue.main.async {
                    self?.loadRecords(records)
                    self?.state = .loaded(count: self?.recordCount ?? 0)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.state = .error("Failed to load cached database")
                }
            }
        }
    }

    private func loadRecords(_ records: [DMRRecord]) {
        recordsByID.removeAll()
        recordsByCallsign.removeAll()

        for record in records {
            recordsByID[record.id] = record
            recordsByCallsign[record.callsign.uppercased()] = record
        }

        recordCount = records.count
    }

    private func saveDatabase(_ records: [DMRRecord]) throws {
        // Ensure directory exists
        let directory = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Save records
        let data = try JSONEncoder().encode(records)
        try data.write(to: databaseURL)
    }

    private func saveMetadata() {
        let now = Date()
        lastUpdated = now
        let metadata = DatabaseMetadata(lastUpdated: now)
        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: metadataURL)
        }
    }
}

// MARK: - API Response Types

private struct RadioIDAPIResponse: Codable {
    let count: Int
    let results: [DMRIDService.DMRRecord]
}

private struct DatabaseMetadata: Codable {
    let lastUpdated: Date
}

// MARK: - Preview Support

extension DMRIDService {
    /// Creates a preview instance with sample data.
    static var preview: DMRIDService {
        let service = DMRIDService()
        service.loadRecords([
            DMRRecord(id: 3123456, callsign: "W1ABC", name: "John Smith", city: "Boston", state: "MA", country: "United States"),
            DMRRecord(id: 3123457, callsign: "K2XYZ", name: "Jane Doe", city: "New York", state: "NY", country: "United States"),
            DMRRecord(id: 3123458, callsign: "N3DEF", name: "Bob Johnson", city: "Philadelphia", state: "PA", country: "United States"),
        ])
        service.state = .loaded(count: 3)
        return service
    }
}
