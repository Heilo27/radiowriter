import Testing
@testable import RadioCore

@Suite("BinaryPacker Tests")
struct BinaryPackerTests {

    @Test("Write and read single bits")
    func writeBits() {
        var packer = BinaryPacker(size: 4)
        packer.writeBit(true)
        packer.writeBit(false)
        packer.writeBit(true)
        packer.writeBit(true)

        let data = packer.result
        // Bits: 1011 0000 = 0xB0
        #expect(data[0] == 0xB0)
    }

    @Test("Write multi-bit values")
    func writeMultiBits() {
        var packer = BinaryPacker(size: 4)
        packer.writeBits(0b1010, count: 4)
        packer.writeBits(0b1100, count: 4)

        let data = packer.result
        // Combined: 1010 1100 = 0xAC
        #expect(data[0] == 0xAC)
    }

    @Test("Write UInt8 byte-aligned")
    func writeUInt8Aligned() {
        var packer = BinaryPacker(size: 4)
        packer.writeUInt8(0x42)
        packer.writeUInt8(0xFF)

        let data = packer.result
        #expect(data[0] == 0x42)
        #expect(data[1] == 0xFF)
    }

    @Test("Write UInt16 little-endian")
    func writeUInt16LE() {
        var packer = BinaryPacker(size: 4)
        packer.writeUInt16LE(0x1234)

        let data = packer.result
        #expect(data[0] == 0x34)
        #expect(data[1] == 0x12)
    }

    @Test("Write UInt16 big-endian")
    func writeUInt16BE() {
        var packer = BinaryPacker(size: 4)
        packer.writeUInt16BE(0x1234)

        let data = packer.result
        #expect(data[0] == 0x12)
        #expect(data[1] == 0x34)
    }

    @Test("Write UInt32 little-endian")
    func writeUInt32LE() {
        var packer = BinaryPacker(size: 4)
        packer.writeUInt32LE(0x12345678)

        let data = packer.result
        #expect(data[0] == 0x78)
        #expect(data[1] == 0x56)
        #expect(data[2] == 0x34)
        #expect(data[3] == 0x12)
    }

    @Test("Write null-padded string")
    func writeString() {
        var packer = BinaryPacker(size: 8)
        packer.writeString("Hi", fixedLength: 8)

        let data = packer.result
        #expect(data[0] == 0x48) // 'H'
        #expect(data[1] == 0x69) // 'i'
        #expect(data[2] == 0x00) // null padding
        #expect(data[7] == 0x00)
    }

    @Test("Seek to bit position")
    func seekBit() {
        var packer = BinaryPacker(size: 4)
        packer.seek(toBit: 12)
        packer.writeBits(0xF, count: 4)

        let data = packer.result
        // Byte 1, lower nibble = 0x0F
        #expect(data[1] == 0x0F)
    }
}
