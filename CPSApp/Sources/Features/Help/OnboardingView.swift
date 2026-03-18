import SwiftUI

// MARK: - Onboarding Page Model

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let body: String
    let icon: String
    let iconColor: Color
    let tips: [String]
}

// MARK: - Onboarding Pages

private let onboardingPages: [OnboardingPage] = [
    OnboardingPage(
        title: "Welcome to RadioWriter",
        subtitle: "Radio Programming Made Simple",
        body: "RadioWriter helps you configure MOTOTRBO radios by reading and writing the radio's codeplug — its complete settings file — directly from your Mac.",
        icon: "antenna.radiowaves.left.and.right",
        iconColor: .blue,
        tips: [
            "Connect your radio via USB before reading or writing",
            "The radio must be powered on — not just charging",
            "Always back up your codeplug before making changes"
        ]
    ),

    OnboardingPage(
        title: "Zones and Channels",
        subtitle: "How Radio Programming is Organized",
        body: "Your radio's channels are organized into Zones — like folders. Each Zone contains related channels, and you switch between them on the radio's channel selector.",
        icon: "folder.badge.gearshape",
        iconColor: .orange,
        tips: [
            "A Zone might be 'Work Repeaters' or 'Simplex Channels'",
            "Each Zone can hold up to 160 channels",
            "Channels store frequency, tone, power, and mode settings"
        ]
    ),

    OnboardingPage(
        title: "Analog vs. Digital",
        subtitle: "Two Types of Channels",
        body: "Your radio can operate in Analog FM (traditional) or Digital DMR mode. Most modern systems use Digital — it fits two calls on one frequency and supports talkgroups, GPS, and encryption.",
        icon: "waveform",
        iconColor: .purple,
        tips: [
            "Analog: use CTCSS (PL) or DCS tones to filter traffic",
            "Digital: set Color Code, Timeslot, and Talkgroup (Contact)",
            "Hover over any field to see an explanation of what it does"
        ]
    ),

    OnboardingPage(
        title: "Reading and Writing",
        subtitle: "Programming Your Radio",
        body: "Use Read to download your radio's current settings. Edit them in RadioWriter. Use Write to upload changes back to the radio. RadioWriter will prompt you to back up before every write.",
        icon: "arrow.up.arrow.down.circle",
        iconColor: .green,
        tips: [
            "Read first — never write to a radio without reading its current config",
            "Verify your changes in the preview before writing",
            "Keep backups of working codeplugs in case you need to restore"
        ]
    ),

    OnboardingPage(
        title: "Getting Help",
        subtitle: "Help is Built Right In",
        body: "Every setting has a tooltip — hover over any label to see what it does and why it matters. Complex sections have a ? button with more detailed guidance. The Glossary explains all technical terms.",
        icon: "questionmark.circle",
        iconColor: .teal,
        tips: [
            "Hover over any field label to see its tooltip",
            "Look for ? buttons in section headers for deeper explanations",
            "Open the Glossary from the Help menu for term definitions"
        ]
    ),
]

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            OnboardingPageView(page: onboardingPages[currentPage])
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: currentPage)

            Divider()

            // Navigation footer
            HStack(spacing: 20) {
                // Back button
                Button("Back") {
                    withAnimation {
                        currentPage = max(0, currentPage - 1)
                    }
                }
                .disabled(currentPage == 0)
                .keyboardShortcut(.leftArrow, modifiers: [])

                // Page dots
                HStack(spacing: 8) {
                    ForEach(onboardingPages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                            .onTapGesture {
                                withAnimation {
                                    currentPage = index
                                }
                            }
                    }
                }

                // Next / Done button
                if currentPage < onboardingPages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
        .frame(width: 560, height: 480)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Skip") {
                    completeOnboarding()
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

// MARK: - Onboarding Page View

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 0) {
            // Icon
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: page.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(page.iconColor)
            }
            .padding(.top, 36)
            .padding(.bottom, 20)

            // Title
            Text(page.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .padding(.bottom, 16)

            // Body
            Text(page.body)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary.opacity(0.85))
                .frame(maxWidth: 420)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            // Tips
            VStack(alignment: .leading, spacing: 10) {
                ForEach(page.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(page.iconColor)
                            .font(.subheadline)
                            .padding(.top, 1)
                        Text(tip)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 48)

            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
