import SwiftUI

// MARK: - Glossary Term

struct GlossaryTerm: Identifiable, Hashable {
    let id = UUID()
    let term: String
    let category: GlossaryCategory
    let definition: String
    let also: String?

    init(_ term: String, category: GlossaryCategory, _ definition: String, also: String? = nil) {
        self.term = term
        self.category = category
        self.definition = definition
        self.also = also
    }
}

enum GlossaryCategory: String, CaseIterable {
    case general = "General"
    case analog = "Analog"
    case digital = "Digital (DMR)"
    case safety = "Safety Features"
    case programming = "Programming"

    var icon: String {
        switch self {
        case .general: return "book"
        case .analog: return "waveform.path"
        case .digital: return "waveform"
        case .safety: return "shield"
        case .programming: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - Glossary Data

private let glossaryTerms: [GlossaryTerm] = [
    // MARK: General
    GlossaryTerm("Codeplug", category: .general,
        "The configuration file that stores all of a radio's settings — channels, contacts, zones, tones, and system parameters. Reading a codeplug downloads it from the radio; writing uploads it back. Think of it as the radio's programming file.",
        also: "CPS file, .cpsx"),

    GlossaryTerm("Zone", category: .general,
        "A named group of channels that appear together on the radio's channel selector. Zones are used to organize channels by location, talkgroup, or purpose — e.g., 'Downtown Repeaters', 'Simplex Channels', or 'Work'. Each zone can hold up to 160 channels."),

    GlossaryTerm("Channel", category: .general,
        "A stored frequency configuration including RX/TX frequencies, tones, power level, and mode (analog or digital). Channels are grouped into zones. The radio switches channels via the channel selector knob or keypad."),

    GlossaryTerm("PTT", category: .general,
        "Push-To-Talk. The button you hold while speaking to transmit. Release it to listen. Most radios have a dedicated PTT button on the side. VOX can automate PTT using voice activation.",
        also: "Push-to-talk"),

    GlossaryTerm("Squelch", category: .general,
        "A circuit that suppresses audio output (mutes the speaker) when no signal is being received, preventing constant background noise. When a signal strong enough to break squelch is received, audio plays. Tone squelch (CTCSS/DCS) adds additional filtering."),

    GlossaryTerm("Simplex", category: .general,
        "Direct radio-to-radio communication on a single frequency without a repeater. Both radios transmit and receive on the same frequency. Range is limited to line-of-sight between radios.",
        also: "Direct, talkaround"),

    GlossaryTerm("Duplex", category: .general,
        "Transmitting and receiving on different frequencies simultaneously (full duplex) or with a frequency offset (half duplex via repeater). Repeater operation uses duplex: your radio transmits on one frequency and the repeater re-transmits on another.",
        also: "Offset, split"),

    GlossaryTerm("Repeater", category: .general,
        "A receiver-transmitter that listens on one frequency (input) and simultaneously re-transmits on another (output), extending range far beyond what direct radio-to-radio contact allows. Most repeaters are placed on hilltops, towers, or tall buildings.",
        also: "Base station"),

    GlossaryTerm("TOT", category: .general,
        "Timeout Timer. Automatically stops transmission after a set time to prevent accidentally blocking the channel. When TOT expires, the radio beeps and releases the PTT. Set to 0 to disable. Typical values: 60–180 seconds.",
        also: "Timeout Timer"),

    GlossaryTerm("VOX", category: .general,
        "Voice Operated Exchange. Automatically keys the transmitter when it detects voice, eliminating the need to press PTT. Useful for hands-free operation. Sensitivity determines how loud a sound must be to trigger transmission.",
        also: "Voice activated transmission"),

    GlossaryTerm("VHF", category: .general,
        "Very High Frequency. Radio band from 136–174 MHz. VHF signals travel well in open terrain and through foliage but are blocked by terrain. Commonly used for public safety, marine, and aviation.",
        also: "136–174 MHz"),

    GlossaryTerm("UHF", category: .general,
        "Ultra High Frequency. Radio band from 400–527 MHz. UHF penetrates buildings and urban environments better than VHF. Used widely for business radios, public safety, and DMR systems.",
        also: "400–527 MHz"),

    GlossaryTerm("Scan List", category: .general,
        "A list of channels the radio automatically monitors when scanning. When the radio detects activity on a scanned channel, it pauses and plays the audio. Scanning is useful for monitoring multiple channels without manually switching between them."),

    GlossaryTerm("RX Group List", category: .general,
        "A list of DMR talkgroups the radio will monitor on a digital channel. When a transmission from any group in the list is received, the radio opens squelch and plays the audio. Allows monitoring multiple talkgroups on one channel."),

    // MARK: Analog
    GlossaryTerm("CTCSS", category: .analog,
        "Continuous Tone-Coded Squelch System. A subaudible tone (67–254.1 Hz) transmitted continuously below voice audio. Receiving radios programmed to the same tone will open squelch; those set to a different tone or no tone will not hear the transmission.",
        also: "PL tone, Private Line, subtone"),

    GlossaryTerm("DCS", category: .analog,
        "Digital-Coded Squelch. Uses a continuous digital data stream (67 Hz bit stream) below voice to selectively open squelch, similar to CTCSS but with more available codes. Each code has a Normal (N) and Inverted (I) polarity — both must match.",
        also: "DPL, Digital Private Line, CDCSS"),

    GlossaryTerm("PL Tone", category: .analog,
        "Shorthand for Private Line tone — Motorola's marketing term for CTCSS. Identical in function to CTCSS. Often used interchangeably. Repeater operators post their PL tone so users can program it into their radios.",
        also: "CTCSS, subtone"),

    GlossaryTerm("Bandwidth", category: .analog,
        "The width of the radio channel in frequency. 12.5 kHz (Narrow FM) is FCC-mandated for Part 90 land mobile radios since 2013. 25 kHz (Wide FM) is the older standard and still used by some legacy systems. Use 12.5 kHz unless your system requires 25 kHz.",
        also: "Deviation, NFM, WFM"),

    GlossaryTerm("TX Tone / RX Tone", category: .analog,
        "TX Tone is the CTCSS or DCS code your radio transmits when keying. RX Tone (also called Receive Squelch) is the code your radio requires before opening the speaker. They are often the same, but can differ on some systems."),

    // MARK: Digital (DMR)
    GlossaryTerm("DMR", category: .digital,
        "Digital Mobile Radio. An open digital radio standard (ETSI TS 102 361) that uses TDMA (time division multiple access) to carry two digital voice channels on a single 12.5 kHz frequency. Used by commercial, public safety, and amateur radio operators worldwide.",
        also: "Digital Mobile Radio, MOTOTRBO, Tier II/III"),

    GlossaryTerm("MOTOTRBO", category: .digital,
        "Motorola's brand name for their DMR product line, including the XPR, SL, DP, and APX series. MOTOTRBO radios are fully compliant with the DMR standard and interoperate with other DMR radios, though some proprietary features are Motorola-specific."),

    GlossaryTerm("Talkgroup", category: .digital,
        "A DMR group address (numeric ID) that routes calls to a set of subscribed radios. Similar in concept to a channel in analog, but a single DMR channel can carry multiple talkgroups. Networks like BrandMeister organize talkgroups by region, language, and interest.",
        also: "Group ID, TG"),

    GlossaryTerm("Color Code", category: .digital,
        "A DMR network identifier (0–15) assigned to a repeater or system. All radios must match the Color Code to join calls on that system. Functions like CTCSS for digital channels — prevents your radio from picking up transmissions from an adjacent system on the same frequency.",
        also: "CC"),

    GlossaryTerm("Timeslot", category: .digital,
        "DMR uses TDMA to split one frequency into two time slots (TS1 and TS2), effectively doubling channel capacity. Each timeslot can carry an independent call simultaneously. Repeaters commonly dedicate each slot to different purposes — check your network's plan.",
        also: "TS1, TS2, TDMA slot"),

    GlossaryTerm("TDMA", category: .digital,
        "Time Division Multiple Access. The technology DMR uses to fit two voice channels onto one 12.5 kHz frequency by alternating between them 30 times per second. Each alternation is one 'time slot'. TDMA doubles the efficiency of spectrum use versus analog.",
        also: "Time Division Multiple Access"),

    GlossaryTerm("BrandMeister", category: .digital,
        "A large global DMR network that interconnects repeaters and hotspots via the internet. Talkgroups on BrandMeister are numbered by region (e.g., 310 for USA) and interest. Amateur radio operators can use BrandMeister with a valid callsign and registered DMR ID."),

    GlossaryTerm("DMR ID", category: .digital,
        "A unique numeric identifier (5–7 digits) for each DMR radio or user. On amateur networks, DMR IDs are tied to callsigns and registered at radioid.net. On commercial networks, IDs are assigned by the system administrator. Every radio must have a unique ID.",
        also: "Subscriber ID, RadioID"),

    GlossaryTerm("Private Call", category: .digital,
        "A one-to-one DMR call addressed to a specific radio's DMR ID. Only the intended radio receives the audio. Useful for individual communications on a shared channel. The recipient's radio must be programmed to accept calls from your ID."),

    GlossaryTerm("Group Call", category: .digital,
        "A DMR call addressed to a talkgroup ID, received by all radios subscribed to that group. The most common call type in DMR systems. Equivalent to a regular transmission on an analog channel shared by a group."),

    GlossaryTerm("All Call", category: .digital,
        "A DMR call addressed to all radios on the channel, regardless of talkgroup. Cannot be blocked by RX group lists. Use sparingly — it interrupts all users. Typically reserved for emergency or broadcast announcements."),

    GlossaryTerm("Hang Time", category: .digital,
        "The duration (in milliseconds) a DMR channel stays assigned to a talkgroup or private call after the last transmission ends. During hang time, the radio monitors for a reply. Too short causes missed replies; too long delays other traffic. Typical: 3000–6000 ms."),

    // MARK: Safety Features
    GlossaryTerm("Lone Worker", category: .safety,
        "A safety feature that periodically prompts the radio user to check in. If the user doesn't respond within a set time, the radio escalates to an audible alert and may transmit an emergency call. Designed for workers operating alone in hazardous or remote environments."),

    GlossaryTerm("Man Down", category: .safety,
        "A safety feature using the radio's accelerometer (motion sensor) to detect if the radio has been horizontal (flat) for longer than the configured delay — indicating the user may have fallen. Triggers an alert if the user doesn't cancel it within the response window."),

    GlossaryTerm("Remote Monitor", category: .safety,
        "Allows a dispatcher or controller to silently open the microphone on a remote radio to listen to its surroundings. The monitored user receives no indication this is happening. Used only in managed fleet deployments where all users are informed."),

    GlossaryTerm("Radio Check", category: .safety,
        "A command sent to verify that a radio is powered on and reachable. The targeted radio automatically sends a status response — no manual action required from the user. Used by dispatchers for fleet presence monitoring."),

    GlossaryTerm("Emergency Call", category: .safety,
        "A priority transmission that interrupts other traffic and alerts dispatchers. Activated by a dedicated emergency button. Emergency calls typically include GPS coordinates (if enabled) and may use a dedicated emergency talkgroup."),

    // MARK: Programming
    GlossaryTerm("Read", category: .programming,
        "Downloading the current codeplug from the radio into RadioWriter. The radio must be connected via USB and powered on. Reading overwrites any unsaved changes in RadioWriter with the radio's current configuration.",
        also: "Upload from radio, clone from radio"),

    GlossaryTerm("Write", category: .programming,
        "Uploading the codeplug from RadioWriter to the radio. The radio must be connected via USB and powered on. Writing replaces the radio's current configuration — always backup first. The radio will restart after a successful write.",
        also: "Download to radio, program radio"),

    GlossaryTerm("XNL", category: .programming,
        "The network protocol used by MOTOTRBO radios for programming over their USB CDC-ECM network connection. RadioWriter communicates with the radio at 192.168.10.1 using XNL (Xenon Network Layer) to read and write the codeplug.",
        also: "Xenon Network Layer, 192.168.10.1"),

    GlossaryTerm("CDC-ECM", category: .programming,
        "USB Communications Device Class – Ethernet Control Model. The USB protocol MOTOTRBO radios use to appear as a network adapter when connected via USB. macOS supports CDC-ECM natively — no drivers needed. The radio appears as a USB network interface.",
        also: "USB Ethernet, USB network adapter"),

    GlossaryTerm("Backup", category: .programming,
        "A saved copy of the codeplug from before programming changes. Always create a backup before writing to the radio. If the new codeplug causes problems, the backup can be restored. RadioWriter prompts to backup before writing."),
]

// MARK: - Glossary View

struct GlossaryView: View {
    @State private var searchText = ""
    @State private var selectedCategory: GlossaryCategory?
    @State private var selectedTerm: GlossaryTerm?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } content: {
            termList
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            termDetail
        }
        .navigationTitle("Glossary")
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search terms")
    }

    // MARK: - Sidebar (Category List)

    private var sidebar: some View {
        List(selection: $selectedCategory) {
            Label("All Terms", systemImage: "book")
                .tag(Optional<GlossaryCategory>.none)

            Divider()

            ForEach(GlossaryCategory.allCases, id: \.self) { category in
                Label(category.rawValue, systemImage: category.icon)
                    .tag(Optional(category))
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Term List

    private var termList: some View {
        Group {
            if filteredTerms.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredTerms, selection: $selectedTerm) { term in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(term.term)
                            .font(.body)
                        Text(term.category.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(term)
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(selectedCategory?.rawValue ?? "All Terms")
    }

    // MARK: - Term Detail

    @ViewBuilder
    private var termDetail: some View {
        if let term = selectedTerm {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text(term.term)
                            .font(.largeTitle.bold())

                        Label(term.category.rawValue, systemImage: term.category.icon)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Definition
                    Text(term.definition)
                        .font(.body)
                        .lineSpacing(4)

                    // Also known as
                    if let also = term.also {
                        GroupBox("Also Known As") {
                            Text(also)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ContentUnavailableView {
                Label("Select a Term", systemImage: "book.pages")
            } description: {
                Text("Choose a term from the list to read its definition.")
            }
        }
    }

    // MARK: - Filtering

    private var filteredTerms: [GlossaryTerm] {
        var terms = glossaryTerms

        if let category = selectedCategory {
            terms = terms.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            terms = terms.filter {
                $0.term.lowercased().contains(query) ||
                $0.definition.lowercased().contains(query) ||
                ($0.also?.lowercased().contains(query) ?? false)
            }
        }

        return terms.sorted { $0.term < $1.term }
    }
}

#Preview {
    GlossaryView()
        .frame(width: 800, height: 500)
}
