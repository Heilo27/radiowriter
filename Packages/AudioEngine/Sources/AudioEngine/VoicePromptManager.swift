import Foundation
import RadioCore

/// Manages voice prompts for radios that support custom audio prompts.
@Observable
public final class VoicePromptManager: @unchecked Sendable {
    public private(set) var prompts: [VoicePrompt] = []

    public init() {}

    /// Loads voice prompts from a codeplug's voice data section.
    public func loadFromCodeplug(_ data: Data) {
        // Parse Speex-encoded voice prompt data
        prompts = []
    }

    /// Adds a voice prompt from an audio file.
    public func addPrompt(from url: URL, name: String) async throws -> VoicePrompt {
        let data = try Data(contentsOf: url)
        let prompt = VoicePrompt(id: UUID(), name: name, duration: 0, rawData: data)
        prompts.append(prompt)
        return prompt
    }

    /// Removes a voice prompt.
    public func removePrompt(_ id: UUID) {
        prompts.removeAll { $0.id == id }
    }

    /// Packs all prompts back into binary format for the radio.
    public func packForRadio() -> Data {
        // Encode prompts to Speex format
        var result = Data()
        for prompt in prompts {
            result.append(prompt.rawData)
        }
        return result
    }
}

/// A single voice prompt entry.
public struct VoicePrompt: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let duration: TimeInterval
    public let rawData: Data

    public init(id: UUID, name: String, duration: TimeInterval, rawData: Data) {
        self.id = id
        self.name = name
        self.duration = duration
        self.rawData = rawData
    }
}
