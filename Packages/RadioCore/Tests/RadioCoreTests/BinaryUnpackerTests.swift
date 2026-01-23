import Testing
import Foundation
@testable import RadioCore

@Suite("BinaryUnpacker Tests")
struct BinaryUnpackerTests {

    @Test("Read single bits")
    func readBits() {
        let data = Data([0xB0]) // 1011 0000
        var unpacker = BinaryUnpacker(data: data)

        #expect(unpacker.readBit() == true)
        #expect(unpacker.readBit() == false)
        #expect(unpacker.readBit() == true)
        #expect(unpacker.readBit() == true)
        #expect(unpacker.readBit() == false)
    }

    @Test("Read multi-bit values")
    func readMultiBits() {
        let data = Data([0xAC]) // 1010 1100
        var unpacker = BinaryUnpacker(data: data)

        let high = unpacker.readBits(count: 4) // 1010 = 10
        let low = unpacker.readBits(count: 4)  // 1100 = 12
        #expect(high == 10)
        #expect(low == 12)
    }

    @Test("Read UInt8")
    func readUInt8() {
        let data = Data([0x42, 0xFF])
        var unpacker = BinaryUnpacker(data: data)

        #expect(unpacker.readUInt8() == 0x42)
        #expect(unpacker.readUInt8() == 0xFF)
    }

    @Test("Read UInt16 little-endian")
    func readUInt16LE() {
        let data = Data([0x34, 0x12])
        var unpacker = BinaryUnpacker(data: data)
        #expect(unpacker.readUInt16LE() == 0x1234)
    }

    @Test("Read UInt16 big-endian")
    func readUInt16BE() {
        let data = Data([0x12, 0x34])
        var unpacker = BinaryUnpacker(data: data)
        #expect(unpacker.readUInt16BE() == 0x1234)
    }

    @Test("Read UInt32 little-endian")
    func readUInt32LE() {
        let data = Data([0x78, 0x56, 0x34, 0x12])
        var unpacker = BinaryUnpacker(data: data)
        #expect(unpacker.readUInt32LE() == 0x12345678)
    }

    @Test("Read null-terminated string")
    func readString() {
        let data = Data([0x48, 0x69, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        var unpacker = BinaryUnpacker(data: data)
        let str = unpacker.readString(fixedLength: 8)
        #expect(str == "Hi")
    }

    @Test("Seek and read")
    func seekAndRead() {
        let data = Data([0x00, 0x0F, 0x00, 0x00]) // Byte 1 lower nibble = F
        var unpacker = BinaryUnpacker(data: data)
        unpacker.seek(toBit: 12)
        let value = unpacker.readBits(count: 4)
        #expect(value == 0xF)
    }

    @Test("Round-trip packer/unpacker")
    func roundTrip() {
        var packer = BinaryPacker(size: 16)
        packer.writeUInt8(0xAB)
        packer.writeUInt16LE(0x1234)
        packer.writeUInt32LE(0xDEADBEEF)
        packer.writeString("OK", fixedLength: 4)

        var unpacker = BinaryUnpacker(data: packer.result)
        #expect(unpacker.readUInt8() == 0xAB)
        #expect(unpacker.readUInt16LE() == 0x1234)
        #expect(unpacker.readUInt32LE() == 0xDEADBEEF)
        #expect(unpacker.readString(fixedLength: 4) == "OK")
    }
}
