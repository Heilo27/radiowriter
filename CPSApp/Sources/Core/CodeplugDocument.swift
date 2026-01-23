import SwiftUI
import UniformTypeIdentifiers
import RadioCore

/// Document type for codeplug files.
struct CodeplugDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.cpsx, .cpsLegacy] }
    static var writableContentTypes: [UTType] { [.cpsx] }

    var codeplug: Codeplug?
    var modelIdentifier: String

    init(codeplug: Codeplug? = nil, modelIdentifier: String = "CLP1010") {
        self.codeplug = codeplug
        self.modelIdentifier = modelIdentifier
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let serializer = CodeplugSerializer()
        let codeplug = try serializer.deserialize(data)
        self.codeplug = codeplug
        self.modelIdentifier = codeplug.modelIdentifier
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let codeplug = codeplug else {
            throw CocoaError(.fileWriteUnknown)
        }

        let serializer = CodeplugSerializer()
        let data = try serializer.serialize(codeplug)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - UTType Extensions

extension UTType {
    /// Native CPS file format (compressed + optional encryption).
    static let cpsx = UTType(exportedAs: "com.heiloprojects.cpsx")

    /// Legacy Windows CPS format (read-only import).
    static let cpsLegacy = UTType(importedAs: "com.motorola.cps")
}
