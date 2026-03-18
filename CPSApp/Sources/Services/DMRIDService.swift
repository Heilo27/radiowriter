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

    /// Descriptive text for the current loading operation.
    @Published var progressDescription: String = ""

    /// Last database update time.
    @Published var lastUpdated: Date?

    /// Number of records in the database.
    @Published var recordCount: Int = 0

    /// Active download task, kept for cancellation support.
    private var currentDownloadTask: Task<Void, Never>?

    /// In-memory index for fast lookups.
    private var recordsByID: [UInt32: DMRRecord] = [:]
    private var recordsByCallsign: [String: DMRRecord] = [:]
    private var recordsByNamePrefix: [String: [DMRRecord]] = [:]

    /// Application Support directory, falling back to temporary directory if unavailable.
    private var appSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    /// Path to the cached database file.
    private var databaseURL: URL {
        appSupportDirectory.appendingPathComponent("RadioWriter/dmrid-database.json")
    }

    /// Path to metadata file.
    private var metadataURL: URL {
        appSupportDirectory.appendingPathComponent("RadioWriter/dmrid-metadata.json")
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

        // Finally search names via prefix index
        let nameKey = String(lowercased.prefix(3))
        if !nameKey.isEmpty, let bucket = recordsByNamePrefix[nameKey] {
            for record in bucket {
                if record.name.lowercased().contains(lowercased) &&
                   !results.contains(where: { $0.id == record.id }) {
                    results.append(record)
                    if results.count >= limit { return results }
                }
            }
        }

        return results
    }

    /// Starts a database download, storing the task for cancellation support.
    /// - Parameter forceRefresh: If true, downloads even if cache is recent
    func startDownload(forceRefresh: Bool = false) {
        currentDownloadTask?.cancel()
        currentDownloadTask = Task {
            await downloadDatabase(forceRefresh: forceRefresh)
        }
    }

    /// Cancels any active database download.
    func cancelDownload() {
        currentDownloadTask?.cancel()
        currentDownloadTask = nil
        if case .loading = state {
            state = .idle
        }
        progressDescription = ""
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
        progressDescription = "Connecting to RadioID.net..."

        do {
            // RadioID.net provides a JSON API for user data
            // Note: This uses the public API endpoint
            let url = URL(string: "https://radioid.net/api/dmr/user/")!

            try Task.checkCancellation()
            progressDescription = "Downloading database..."
            let (data, response) = try await URLSession.shared.data(from: url)

            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                state = .error("Couldn't download the DMR ID database. Check your internet connection and try again.")
                progressDescription = ""
                return
            }

            state = .loading(progress: 0.5)
            let sizeKB = data.count / 1024
            progressDescription = "Parsing \(sizeKB) KB of data..."

            // Parse the JSON response
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(RadioIDAPIResponse.self, from: data)

            try Task.checkCancellation()
            state = .loading(progress: 0.7)
            progressDescription = "Saving \(apiResponse.results.count.formatted()) records..."

            // Save to cache
            try saveDatabase(apiResponse.results)

            // Load into memory
            loadRecords(apiResponse.results)

            // Save metadata
            saveMetadata()

            state = .loaded(count: recordCount)
            progressDescription = ""

        } catch is CancellationError {
            state = .idle
            progressDescription = ""
        } catch {
            state = .error("Couldn't update the DMR ID database. Check your internet connection and try again.")
            progressDescription = ""
        }
    }

    /// Clears the local database cache.
    func clearCache() {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(at: metadataURL)
        recordsByID.removeAll()
        recordsByCallsign.removeAll()
        recordsByNamePrefix.removeAll()
        recordCount = 0
        lastUpdated = nil
        state = .idle
    }

    // MARK: - Private Methods

    private func loadCachedDatabase() {
        // Load metadata synchronously (tiny file)
        if let data = try? Data(contentsOf: metadataURL),
           let metadata = try? JSONDecoder().decode(DatabaseMetadata.self, from: data) {
            lastUpdated = metadata.lastUpdated
        }

        let dbURL = databaseURL
        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            state = .idle
            return
        }

        state = .loading(progress: 0)

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let data = try Data(contentsOf: dbURL)
                let records = try JSONDecoder().decode([DMRIDService.DMRRecord].self, from: data)
                await MainActor.run { [weak self] in
                    self?.loadRecords(records)
                    self?.state = .loaded(count: self?.recordCount ?? 0)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.state = .error("Failed to load cached database")
                }
            }
        }
    }

    private func loadRecords(_ records: [DMRRecord]) {
        recordsByID.removeAll()
        recordsByCallsign.removeAll()
        recordsByNamePrefix.removeAll()

        var nameIndex: [String: [DMRRecord]] = [:]
        for record in records {
            recordsByID[record.id] = record
            recordsByCallsign[record.callsign.uppercased()] = record
            let key = String(record.name.lowercased().prefix(3))
            if !key.isEmpty {
                nameIndex[key, default: []].append(record)
            }
        }
        recordsByNamePrefix = nameIndex

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
