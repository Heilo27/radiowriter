import Testing
import Foundation
@testable import AudioEngine

@Suite("VoicePrompt Tests")
struct VoicePromptTests {

    @Test("Voice prompt manager starts empty")
    func startsEmpty() {
        let manager = VoicePromptManager()
        #expect(manager.prompts.isEmpty)
    }

    @Test("Remove prompt by ID")
    func removePrompt() async throws {
        let manager = VoicePromptManager()

        // Create a temp file for testing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.wav")
        try Data([0x00, 0x01, 0x02]).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let prompt = try await manager.addPrompt(from: tempURL, name: "Test")
        #expect(manager.prompts.count == 1)

        manager.removePrompt(prompt.id)
        #expect(manager.prompts.isEmpty)
    }
}
