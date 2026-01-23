import Testing
import Foundation
@testable import RadioCore

@Suite("Codeplug Tests")
struct CodeplugTests {

    @Test("Create empty codeplug")
    func createEmpty() {
        let codeplug = Codeplug(modelIdentifier: "TEST", size: 64)
        #expect(codeplug.modelIdentifier == "TEST")
        #expect(codeplug.rawData.count == 64)
    }

    @Test("Get and set bool field")
    func boolField() {
        let codeplug = Codeplug(modelIdentifier: "TEST", size: 64)
        let field = FieldDefinition(
            id: "test.bool",
            name: "testBool",
            displayName: "Test Bool",
            category: .general,
            valueType: .bool,
            bitOffset: 0,
            bitLength: 1,
            defaultValue: .bool(false)
        )

        codeplug.setValue(.bool(true), for: field)
        let value = codeplug.getValue(for: field)
        #expect(value == .bool(true))
    }

    @Test("Get and set uint8 field")
    func uint8Field() {
        let codeplug = Codeplug(modelIdentifier: "TEST", size: 64)
        let field = FieldDefinition(
            id: "test.u8",
            name: "testU8",
            displayName: "Test U8",
            category: .general,
            valueType: .uint8,
            bitOffset: 8,
            bitLength: 8,
            defaultValue: .uint8(0)
        )

        codeplug.setValue(.uint8(42), for: field)
        let value = codeplug.getValue(for: field)
        #expect(value == .uint8(42))
    }

    @Test("Get and set uint16 field")
    func uint16Field() {
        let codeplug = Codeplug(modelIdentifier: "TEST", size: 64)
        let field = FieldDefinition(
            id: "test.u16",
            name: "testU16",
            displayName: "Test U16",
            category: .general,
            valueType: .uint16,
            bitOffset: 16,
            bitLength: 16,
            defaultValue: .uint16(0)
        )

        codeplug.setValue(.uint16(1234), for: field)
        let value = codeplug.getValue(for: field)
        #expect(value == .uint16(1234))
    }

    @Test("Get and set uint32 field")
    func uint32Field() {
        let codeplug = Codeplug(modelIdentifier: "TEST", size: 64)
        let field = FieldDefinition(
            id: "test.u32",
            name: "testU32",
            displayName: "Test U32",
            category: .general,
            valueType: .uint32,
            bitOffset: 32,
            bitLength: 32,
            defaultValue: .uint32(0)
        )

        codeplug.setValue(.uint32(462_5625), for: field)
        let value = codeplug.getValue(for: field)
        #expect(value == .uint32(462_5625))
    }

    @Test("Get and set string field")
    func stringField() {
        let codeplug = Codeplug(modelIdentifier: "TEST", size: 64)
        let field = FieldDefinition(
            id: "test.str",
            name: "testStr",
            displayName: "Test String",
            category: .general,
            valueType: .string(maxLength: 8, encoding: .utf8),
            bitOffset: 64,
            bitLength: 64,
            defaultValue: .string("")
        )

        codeplug.setValue(.string("Hello"), for: field)
        let value = codeplug.getValue(for: field)
        #expect(value == .string("Hello"))
    }

    @Test("Constraint validation - range")
    func rangeConstraint() {
        let codeplug = Codeplug(modelIdentifier: "TEST", size: 64)
        let field = FieldDefinition(
            id: "test.ranged",
            name: "testRanged",
            displayName: "Ranged",
            category: .general,
            valueType: .uint8,
            bitOffset: 0,
            bitLength: 8,
            defaultValue: .uint8(5),
            constraint: .range(min: 0, max: 10)
        )

        let validResult = codeplug.setValue(.uint8(5), for: field)
        #expect(validResult.isValid)

        let invalidResult = codeplug.setValue(.uint8(15), for: field)
        #expect(!invalidResult.isValid)
    }

    @Test("Track modified fields")
    func modifications() {
        let codeplug = Codeplug(modelIdentifier: "TEST", size: 64)
        let field = FieldDefinition(
            id: "test.mod",
            name: "testMod",
            displayName: "Modified",
            category: .general,
            valueType: .uint8,
            bitOffset: 0,
            bitLength: 8,
            defaultValue: .uint8(0)
        )

        #expect(!codeplug.isModified("test.mod"))
        codeplug.setValue(.uint8(1), for: field)
        #expect(codeplug.isModified("test.mod"))

        codeplug.clearModifications()
        #expect(!codeplug.isModified("test.mod"))
    }

    @Test("Bit-level field at non-aligned offset")
    func nonAlignedField() {
        let codeplug = Codeplug(modelIdentifier: "TEST", size: 64)
        // 4-bit field starting at bit 5
        let field = FieldDefinition(
            id: "test.nibble",
            name: "testNibble",
            displayName: "Nibble",
            category: .general,
            valueType: .bitField(bitCount: 4),
            bitOffset: 4,
            bitLength: 4,
            defaultValue: .bitField(0, bitCount: 4)
        )

        codeplug.setValue(.bitField(0xA, bitCount: 4), for: field)
        let value = codeplug.getValue(for: field)
        #expect(value == .bitField(0xA, bitCount: 4))
    }
}
