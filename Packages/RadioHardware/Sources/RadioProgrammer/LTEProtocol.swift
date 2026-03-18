import Foundation

// MARK: - LTE/PBB Protocol

// LTE/PBB (Packet-Based Broadband) protocol for programming LTE radios.
// Unlike PCR radios that use serial binary protocols, PBB radios use HTTP/REST APIs.
//
// Transport: HTTP/HTTPS over WiFi or LTE
// Content Types: application/json, application/octet-stream, application/zip

// MARK: - API Endpoints

/// LTE/PBB REST API endpoints.
public enum LTEEndpoint: String, Sendable {
    // Core Operations
    case password = "/password"
    case deviceInventory = "/deviceInventory"
    case appInventory = "/appInventory"
    case licenseInventory = "/licenseInventory"
    case fileCollection = "/fileCollection"
    case terminateSession = "/terminateSession"
    case factoryReset = "/factoryReset"
    case job = "/job"

    // Certificate Management
    case installCACert = "/certificate/installCACert"
    case uninstallAllCACerts = "/certificate/uninstallAllCACerts"
    case enableAllSystemCACerts = "/certificate/enableAllSystemCACerts"
    case disableAllSystemCACerts = "/certificate/disableAllSystemCACerts"

    // Application Management
    case deviceFirmware = "/deviceFirmware"
    case packageFile = "/packageFile"
    case deleteAppInventory = "/deleteAppInventory"

    // Provisioning Operations
    case config = "/config"
    case version = "/version"
    case serial = "/serial"
    case getAliasID = "/get_alias_id"
    case getMode = "/get_mode"
    case authKey = "/authKey"
    case updateUser = "/updateuser"
    case cfsHardwareID = "/cfs_hardware_id"
    case secureAuth = "/secureAuth"
    case resetAuth = "/resetAuth"

    // LMR-Specific
    case lmrCodeplug = "/lmrCodeplug"
}

// MARK: - HTTP Methods

/// HTTP methods for LTE API requests.
public enum LTEHTTPMethod: String, Sendable {
    case GET
    case POST
    case DELETE
    case PUT
}

// MARK: - Session Management

/// Radio operation types for LTE session management.
public enum LTERadioOperation: Int, Sendable {
    case read = 1
    case write = 2
    case update = 3
}

/// LTE session state.
public struct LTESession: Sendable {
    public let sessionID: UInt16
    public let operation: LTERadioOperation
    public let startTime: Date

    public init(sessionID: UInt16? = nil, operation: LTERadioOperation) {
        self.sessionID = sessionID ?? UInt16.random(in: 1...0xFFFE)
        self.operation = operation
        self.startTime = Date()
    }
}

// MARK: - Device Inventory

/// Device inventory response from /deviceInventory endpoint.
public struct LTEDeviceInventory: Codable, Sendable {
    public let model: String?
    public let serial: String?
    public let firmware: String?
    public let codeplugVersion: String?
    public let hardwareVersion: String?
    public let radioID: String?
    public let capabilities: [String]?

    public init(
        model: String? = nil,
        serial: String? = nil,
        firmware: String? = nil,
        codeplugVersion: String? = nil,
        hardwareVersion: String? = nil,
        radioID: String? = nil,
        capabilities: [String]? = nil
    ) {
        self.model = model
        self.serial = serial
        self.firmware = firmware
        self.codeplugVersion = codeplugVersion
        self.hardwareVersion = hardwareVersion
        self.radioID = radioID
        self.capabilities = capabilities
    }

    enum CodingKeys: String, CodingKey {
        case model
        case serial
        case firmware
        case codeplugVersion
        case hardwareVersion
        case radioID
        case capabilities
    }
}

/// Password authentication request.
public struct LTEPasswordRequest: Codable, Sendable {
    public let password: String

    public init(password: String) {
        self.password = password
    }
}

/// Password authentication response.
public struct LTEPasswordResponse: Codable, Sendable {
    public let deviceInventory: LTEDeviceInventory?
    public let error: String?

    public var isSuccess: Bool {
        return error == nil && deviceInventory != nil
    }
}

/// Session termination request.
public struct LTETerminateSessionRequest: Codable, Sendable {
    public let sessionID: Int
    public let code: Int?
    public let reason: String?

    public init(sessionID: Int, code: Int? = nil, reason: String? = nil) {
        self.sessionID = sessionID
        self.code = code
        self.reason = reason
    }
}

// MARK: - File Collection

/// File manifest entry for file collection transfers.
public struct LTEFileManifestEntry: Codable, Sendable {
    public let name: String
    public let size: Int
    public let type: String?
    public let checksum: String?

    public init(name: String, size: Int, type: String? = nil, checksum: String? = nil) {
        self.name = name
        self.size = size
        self.type = type
        self.checksum = checksum
    }
}

/// File collection manifest for upload/download operations.
public struct LTEFileCollection: Codable, Sendable {
    public let fileName: String?
    public let files: [LTEFileManifestEntry]

    public init(fileName: String? = nil, files: [LTEFileManifestEntry]) {
        self.fileName = fileName
        self.files = files
    }
}

/// File collection response from the radio.
public struct LTEFileCollectionResponse: Codable, Sendable {
    public let fileCollection: LTEFileCollection?
    public let error: String?
}

// MARK: - Application/License Inventory

/// Application inventory entry.
public struct LTEApplicationEntry: Codable, Sendable {
    public let name: String
    public let version: String?
    public let packageName: String?
    public let installed: Bool?

    public init(name: String, version: String? = nil, packageName: String? = nil, installed: Bool? = nil) {
        self.name = name
        self.version = version
        self.packageName = packageName
        self.installed = installed
    }
}

/// Application inventory response.
public struct LTEAppInventoryResponse: Codable, Sendable {
    public let applications: [LTEApplicationEntry]?
    public let error: String?
}

/// License/feature entry.
public struct LTELicenseEntry: Codable, Sendable {
    public let featureID: String
    public let name: String?
    public let enabled: Bool
    public let expirationDate: String?

    public init(featureID: String, name: String? = nil, enabled: Bool, expirationDate: String? = nil) {
        self.featureID = featureID
        self.name = name
        self.enabled = enabled
        self.expirationDate = expirationDate
    }
}

/// License inventory response.
public struct LTELicenseInventoryResponse: Codable, Sendable {
    public let licenses: [LTELicenseEntry]?
    public let error: String?
}

// MARK: - Feature Activation

/// Feature activation request.
public struct LTEFeatureActivationRequest: Codable, Sendable {
    public let firmwareVersion: String
    public let serialNumber: String
    public let xmlHashInput: String?
    public let featureCodeIDs: [String]

    public init(firmwareVersion: String, serialNumber: String, xmlHashInput: String? = nil, featureCodeIDs: [String]) {
        self.firmwareVersion = firmwareVersion
        self.serialNumber = serialNumber
        self.xmlHashInput = xmlHashInput
        self.featureCodeIDs = featureCodeIDs
    }
}

// MARK: - Job Status

/// Background job status.
public struct LTEJobStatus: Codable, Sendable {
    public let jobID: String
    public let status: String
    public let progress: Double?
    public let result: String?
    public let error: String?

    public var isComplete: Bool {
        return status == "complete" || status == "completed"
    }

    public var isFailed: Bool {
        return status == "failed" || status == "error"
    }

    public var isInProgress: Bool {
        return status == "running" || status == "in_progress"
    }
}

// MARK: - LTE API Request Builder

/// Builder for LTE REST API requests.
public struct LTERequest: Sendable {
    public let endpoint: LTEEndpoint
    public let method: LTEHTTPMethod
    public let body: Data?
    public let queryParameters: [String: String]?
    public let contentType: String

    public init(
        endpoint: LTEEndpoint,
        method: LTEHTTPMethod = .GET,
        body: Data? = nil,
        queryParameters: [String: String]? = nil,
        contentType: String = "application/json"
    ) {
        self.endpoint = endpoint
        self.method = method
        self.body = body
        self.queryParameters = queryParameters
        self.contentType = contentType
    }

    /// Builds a URL for this request.
    public func buildURL(baseURL: String) -> URL? {
        var urlString = baseURL + endpoint.rawValue

        if let params = queryParameters, !params.isEmpty {
            let queryString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }

        return URL(string: urlString)
    }

    /// Builds a URLRequest for this request.
    public func buildURLRequest(baseURL: String) -> URLRequest? {
        guard let url = buildURL(baseURL: baseURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        return request
    }

    // MARK: - Factory Methods

    /// Creates a password authentication request.
    public static func authenticate(password: String) -> LTERequest {
        let payload = LTEPasswordRequest(password: password)
        let body = try? JSONEncoder().encode(payload)
        return LTERequest(endpoint: .password, method: .POST, body: body)
    }

    /// Creates a device inventory request.
    public static func getDeviceInventory() -> LTERequest {
        return LTERequest(endpoint: .deviceInventory, method: .GET)
    }

    /// Creates an application inventory request.
    public static func getAppInventory() -> LTERequest {
        return LTERequest(endpoint: .appInventory, method: .GET)
    }

    /// Creates a license inventory request.
    public static func getLicenseInventory() -> LTERequest {
        return LTERequest(endpoint: .licenseInventory, method: .GET)
    }

    /// Creates a file collection download request.
    public static func downloadFileCollection(fileName: String) -> LTERequest {
        return LTERequest(
            endpoint: .fileCollection,
            method: .GET,
            queryParameters: ["fileName": fileName],
            contentType: "application/octet-stream"
        )
    }

    /// Creates a file collection upload request.
    public static func uploadFileCollection(data: Data) -> LTERequest {
        return LTERequest(
            endpoint: .fileCollection,
            method: .POST,
            body: data,
            contentType: "application/octet-stream"
        )
    }

    /// Creates a session termination request.
    public static func terminateSession(sessionID: Int, code: Int? = nil, reason: String? = nil) -> LTERequest {
        let payload = LTETerminateSessionRequest(sessionID: sessionID, code: code, reason: reason)
        let body = try? JSONEncoder().encode(payload)
        return LTERequest(endpoint: .terminateSession, method: .POST, body: body)
    }

    /// Creates a job status request.
    public static func getJobStatus(jobID: String) -> LTERequest {
        return LTERequest(
            endpoint: .job,
            method: .GET,
            queryParameters: ["jobID": jobID]
        )
    }

    /// Creates an LMR codeplug download request.
    public static func downloadLMRCodeplug() -> LTERequest {
        return LTERequest(
            endpoint: .lmrCodeplug,
            method: .GET,
            contentType: "application/octet-stream"
        )
    }

    /// Creates an LMR codeplug upload request.
    public static func uploadLMRCodeplug(data: Data) -> LTERequest {
        return LTERequest(
            endpoint: .lmrCodeplug,
            method: .POST,
            body: data,
            contentType: "application/octet-stream"
        )
    }

    /// Creates a factory reset request.
    public static func factoryReset() -> LTERequest {
        return LTERequest(endpoint: .factoryReset, method: .POST)
    }

    /// Creates a serial number request.
    public static func getSerialNumber() -> LTERequest {
        return LTERequest(endpoint: .serial, method: .GET)
    }

    /// Creates a firmware version request.
    public static func getVersion() -> LTERequest {
        return LTERequest(endpoint: .version, method: .GET)
    }

    /// Creates a configuration read request.
    public static func getConfig() -> LTERequest {
        return LTERequest(endpoint: .config, method: .GET)
    }

    /// Creates a configuration write request.
    public static func setConfig(data: Data) -> LTERequest {
        return LTERequest(endpoint: .config, method: .POST, body: data)
    }
}

// MARK: - LTE HTTP Client Protocol

/// Protocol for LTE HTTP communication.
public protocol LTEHTTPClient: Sendable {
    func send(_ request: LTERequest) async throws -> (Data, HTTPURLResponse)
}

// MARK: - LTE Errors

/// Errors specific to LTE/PBB protocol communication.
public enum LTEError: Error, LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case unauthorized
    case notFound(String)
    case badRequest(String)
    case serverError(String)
    case serviceUnavailable
    case timeout
    case invalidResponse
    case jobFailed(String)
    case notImplemented(String)
    case networkError(Error)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed: return "Could not connect to the radio"
        case .authenticationFailed: return "Wrong password"
        case .unauthorized: return "Authentication required"
        case .notFound: return "Feature not available on this radio"
        case .badRequest: return "The radio rejected the request"
        case .serverError: return "The radio reported an internal error"
        case .serviceUnavailable: return "The radio is busy"
        case .timeout: return "The radio stopped responding"
        case .invalidResponse: return "The radio returned unexpected data"
        case .jobFailed: return "The programming operation failed on the radio"
        case .notImplemented: return "This feature is not yet supported for this radio model"
        case .networkError: return "Network error communicating with the radio"
        case .decodingError: return "Could not parse the radio's response"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .connectionFailed:
            return "Make sure the radio is powered on and connected to the same network. Most LEX/SLR radios are reachable at 192.168.10.1."
        case .authenticationFailed:
            return "Enter the radio's programming password. The default is usually blank — check the radio's configuration or contact your system administrator."
        case .unauthorized:
            return "Authenticate with the radio's programming password before performing this operation."
        case .notFound:
            return "This radio model or firmware version may not support this feature. Check that you have the correct radio model selected."
        case .badRequest:
            return "Try restarting the programming session. If this persists, the radio firmware may be incompatible."
        case .serverError:
            return "Power cycle the radio and try again. If the problem persists, the radio may need a firmware update."
        case .serviceUnavailable:
            return "Wait a few seconds and try again. Another device may be programming the radio, or a previous session did not close cleanly."
        case .timeout:
            return "Unplug and reconnect the radio, then power cycle it and try again."
        case .invalidResponse:
            return "The radio firmware may be incompatible with this version of RadioWriter. Try restarting the radio."
        case .jobFailed:
            return "Try reading the codeplug from the radio first to confirm the connection, then attempt the write again."
        case .notImplemented:
            return "This feature will be added in a future update."
        case .networkError:
            return "Check that the radio is still connected to the network and try again."
        case .decodingError:
            return "The radio returned an unexpected format. This may indicate a firmware incompatibility."
        }
    }

    /// Technical details suitable for diagnostic disclosure.
    public var technicalDescription: String {
        switch self {
        case .connectionFailed(let msg): return "LTE connection failed: \(msg)"
        case .authenticationFailed: return "HTTP 401: Authentication failed"
        case .unauthorized: return "HTTP 403: Unauthorized"
        case .notFound(let endpoint): return "HTTP 404: \(endpoint)"
        case .badRequest(let msg): return "HTTP 400: \(msg)"
        case .serverError(let msg): return "HTTP 500: \(msg)"
        case .serviceUnavailable: return "HTTP 503: Service unavailable"
        case .timeout: return "LTE request timed out"
        case .invalidResponse: return "LTE invalid response format"
        case .jobFailed(let msg): return "LTE background job failed: \(msg)"
        case .notImplemented(let msg): return "Not implemented: \(msg)"
        case .networkError(let error): return "Network: \(error.localizedDescription)"
        case .decodingError(let msg): return "JSON decode error: \(msg)"
        }
    }

    /// Creates an LTEError from an HTTP status code.
    public static func fromStatusCode(_ code: Int, message: String? = nil) -> LTEError {
        switch code {
        case 400: return .badRequest(message ?? "Invalid request")
        case 401: return .authenticationFailed
        case 403: return .unauthorized
        case 404: return .notFound(message ?? "Resource not found")
        case 500: return .serverError(message ?? "Internal server error")
        case 503: return .serviceUnavailable
        default: return .serverError("HTTP \(code): \(message ?? "Unknown error")")
        }
    }
}

// MARK: - URLSession-based HTTP Client

/// Default LTE HTTP client using URLSession.
public final class LTEURLSessionClient: LTEHTTPClient, Sendable {
    private let baseURL: String
    private let session: URLSession
    private let timeoutInterval: TimeInterval

    public init(baseURL: String, timeoutInterval: TimeInterval = 30.0) {
        self.baseURL = baseURL
        self.timeoutInterval = timeoutInterval

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval * 2
        self.session = URLSession(configuration: config)
    }

    public func send(_ request: LTERequest) async throws -> (Data, HTTPURLResponse) {
        guard var urlRequest = request.buildURLRequest(baseURL: baseURL) else {
            throw LTEError.connectionFailed("Invalid URL")
        }

        urlRequest.timeoutInterval = timeoutInterval

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LTEError.invalidResponse
            }

            // Check for HTTP errors
            if httpResponse.statusCode >= 400 {
                let message = String(data: data, encoding: .utf8)
                throw LTEError.fromStatusCode(httpResponse.statusCode, message: message)
            }

            return (data, httpResponse)
        } catch let error as LTEError {
            throw error
        } catch {
            throw LTEError.networkError(error)
        }
    }
}
