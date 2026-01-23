import Testing
import Foundation
@testable import RadioModelCore
@testable import CLP
import RadioCore

@Suite("CLP Model Tests")
struct CLPModelTests {

    @Test("CLP1010 creates valid default codeplug")
    func clp1010Default() {
        let codeplug = CLP1010.createDefault()
        #expect(codeplug.modelIdentifier == "CLP1010")
        #expect(codeplug.rawData.count == CLP1010.codeplugSize)

        // Check default frequency
        let freq = codeplug.getValue(for: CLPFields.channel1Frequency)
        #expect(freq == .uint32(4625625))
    }

    @Test("CLP1040 creates valid default codeplug with 4 channels")
    func clp1040Default() {
        let codeplug = CLP1040.createDefault()
        #expect(codeplug.modelIdentifier == "CLP1040")
        #expect(codeplug.rawData.count == CLP1040.codeplugSize)
    }

    @Test("CLP1010 validates frequency range")
    func frequencyValidation() {
        let codeplug = CLP1010.createDefault()

        // Write out-of-range frequency directly to rawData (bypassing constraint)
        // 9999999 in 100Hz units = 999.9999 MHz, outside UHF band
        let outOfRange: UInt32 = 9999999
        let offset = CLPFields.channel1Frequency.bitOffset / 8
        codeplug.rawData[offset] = UInt8((outOfRange >> 24) & 0xFF)
        codeplug.rawData[offset + 1] = UInt8((outOfRange >> 16) & 0xFF)
        codeplug.rawData[offset + 2] = UInt8((outOfRange >> 8) & 0xFF)
        codeplug.rawData[offset + 3] = UInt8(outOfRange & 0xFF)

        let issues = CLP1010.validate(codeplug)
        #expect(!issues.isEmpty)
        #expect(issues.first?.severity == .error)
    }

    @Test("CLP field definitions are correctly structured")
    func fieldStructure() {
        #expect(CLP1010.maxChannels == 1)
        #expect(CLP1040.maxChannels == 4)
        #expect(CLP1010.family == .clp)
        #expect(CLP1010.frequencyBand.name == "UHF")
    }

    @Test("VOX dependency clears sensitivity when disabled")
    func voxDependency() {
        let codeplug = CLP1010.createDefault()
        codeplug.setValue(.bool(true), for: CLPFields.voxEnabled)
        codeplug.setValue(.uint8(4), for: CLPFields.voxSensitivity)

        // Disable VOX
        codeplug.setValue(.bool(false), for: CLPFields.voxEnabled)
        CLP1010.applyDependencies(field: CLPFields.voxEnabled.id, in: codeplug)

        let sensitivity = codeplug.getValue(for: CLPFields.voxSensitivity)
        #expect(sensitivity == .uint8(0))
    }

    @Test("Radio model registry works")
    func registry() {
        RadioModelRegistry.register(CLP1010.self)
        RadioModelRegistry.register(CLP1040.self)

        #expect(RadioModelRegistry.model(for: "CLP1010") != nil)
        #expect(RadioModelRegistry.model(for: "CLP1040") != nil)
        #expect(RadioModelRegistry.model(for: "INVALID") == nil)
    }
}
