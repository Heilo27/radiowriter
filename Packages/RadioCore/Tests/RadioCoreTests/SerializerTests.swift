import Testing
import Foundation
@testable import RadioCore

@Suite("CodeplugSerializer Tests")
struct SerializerTests {

    @Test("Round-trip serialize/deserialize without encryption")
    func roundTripNoEncryption() throws {
        let original = Codeplug(modelIdentifier: "CLP1010", size: 256)
        // Set some data
        original.rawData[0] = 0xAB
        original.rawData[100] = 0xCD
        original.rawData[255] = 0xEF

        let serializer = CodeplugSerializer()
        let serialized = try serializer.serialize(original)
        let restored = try serializer.deserialize(serialized)

        #expect(restored.modelIdentifier == "CLP1010")
        #expect(restored.rawData.count == 256)
        #expect(restored.rawData[0] == 0xAB)
        #expect(restored.rawData[100] == 0xCD)
        #expect(restored.rawData[255] == 0xEF)
    }

    @Test("Round-trip with encryption")
    func roundTripEncrypted() throws {
        let original = Codeplug(modelIdentifier: "TEST", size: 128)
        original.rawData[0] = 0x42

        let serializer = CodeplugSerializer()
        let serialized = try serializer.serialize(original, password: "secret123")
        let restored = try serializer.deserialize(serialized, password: "secret123")

        #expect(restored.rawData[0] == 0x42)
    }

    @Test("Decryption with wrong password fails")
    func wrongPassword() throws {
        let original = Codeplug(modelIdentifier: "TEST", size: 64)
        let serializer = CodeplugSerializer()
        let serialized = try serializer.serialize(original, password: "correct")

        #expect(throws: (any Error).self) {
            _ = try serializer.deserialize(serialized, password: "wrong")
        }
    }

    @Test("Deserialize without password when encrypted fails")
    func missingPassword() throws {
        let original = Codeplug(modelIdentifier: "TEST", size: 64)
        let serializer = CodeplugSerializer()
        let serialized = try serializer.serialize(original, password: "secret")

        #expect(throws: SerializationError.self) {
            _ = try serializer.deserialize(serialized)
        }
    }

    @Test("Invalid format detection")
    func invalidFormat() {
        let serializer = CodeplugSerializer()
        let garbage = Data([0x00, 0x01, 0x02, 0x03])

        #expect(throws: SerializationError.self) {
            _ = try serializer.deserialize(garbage)
        }
    }

    @Test("Metadata preserved through serialization")
    func metadataPreserved() throws {
        let metadata = CodeplugMetadata(
            radioSerialNumber: "ABC123",
            radioModelName: "CLP 1010",
            notes: "Test codeplug"
        )
        let original = Codeplug(modelIdentifier: "CLP1010", rawData: Data(count: 64), metadata: metadata)

        let serializer = CodeplugSerializer()
        let serialized = try serializer.serialize(original)
        let restored = try serializer.deserialize(serialized)

        #expect(restored.metadata.radioSerialNumber == "ABC123")
        #expect(restored.metadata.radioModelName == "CLP 1010")
        #expect(restored.metadata.notes == "Test codeplug")
    }
}
