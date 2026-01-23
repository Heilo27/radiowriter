import Foundation
import RadioCore
import RadioModelCore

// MARK: - CLP1010 Nodes (Single Channel)

let generalNode = CodeplugNode(
    id: "clp.general",
    name: "general",
    displayName: "General",
    category: .general,
    fields: [
        CLPFields.radioAlias,
        CLPFields.txPower,
        CLPFields.totTimeout,
    ]
)

let channelNode = CodeplugNode(
    id: "clp.channel",
    name: "channel",
    displayName: "Channel",
    category: .channel,
    fields: [
        CLPFields.channel1Frequency,
    ]
)

let audioNode = CodeplugNode(
    id: "clp.audio",
    name: "audio",
    displayName: "Audio",
    category: .audio,
    fields: [
        CLPFields.volumeLevel,
        CLPFields.voxEnabled,
        CLPFields.voxSensitivity,
        CLPFields.toneVolume,
        CLPFields.squelchLevel,
    ]
)

let signalingNode = CodeplugNode(
    id: "clp.signaling",
    name: "signaling",
    displayName: "Signaling",
    category: .signaling,
    fields: [
        CLPFields.ctcssTxTone,
        CLPFields.ctcssRxTone,
    ]
)

// MARK: - CLP1040 Nodes (Multi-Channel)

let channelsNode: CodeplugNode = {
    var children: [CodeplugNode] = []
    for ch in 0..<4 {
        children.append(CodeplugNode(
            id: "clp.channel.\(ch)",
            name: "channel\(ch + 1)",
            displayName: "Channel \(ch + 1)",
            category: .channel,
            fields: [
                CLPFields.channelFrequency(channel: ch),
                CLPFields.channelName(channel: ch),
                CLPFields.channelTxTone(channel: ch),
                CLPFields.channelRxTone(channel: ch),
            ]
        ))
    }
    return CodeplugNode(
        id: "clp.channels",
        name: "channels",
        displayName: "Channels",
        category: .channel,
        nodeType: .repeating(count: 4, stride: 128),
        children: children
    )
}()
