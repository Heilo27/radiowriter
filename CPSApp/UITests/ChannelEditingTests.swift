import XCTest

/// Tests for channel editing workflows including frequency changes.
final class ChannelEditingTests: CPSAppUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Navigate to editing phase with a CLP profile
        assertWelcomeScreenVisible()
        createNewProfile(modelID: "clp1010")
        XCTAssertTrue(isEditingPhaseActive())
    }

    // MARK: - Sidebar Navigation

    func testSidebarCategoriesExist() {
        // Verify sidebar categories are present
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 3))

        // Check common categories exist via accessibility identifiers
        let generalItem = app.staticTexts["sidebar.general"].firstMatch
        let channelItem = app.staticTexts["sidebar.channel"].firstMatch

        // At least one sidebar item should exist
        let hasGeneral = generalItem.waitForExistence(timeout: 2)
        let hasChannel = channelItem.waitForExistence(timeout: 2)
        XCTAssertTrue(hasGeneral || hasChannel, "At least one sidebar category should be visible")
    }

    func testNavigateToChannelCategory() {
        selectSidebarCategory("channel")

        // Channel view should display (ZoneChannelView or ChannelEditorView)
        // For a raw codeplug (not parsed), it shows ChannelEditorView with a table
        let channelTable = app.tables["channelTable"].firstMatch
        let zonesHeader = app.staticTexts["Zones"].firstMatch
        let channelsHeader = app.staticTexts["Channels"].firstMatch

        // Either the table-based editor or the zone/channel view should be visible
        let hasChannelContent = channelTable.waitForExistence(timeout: 3)
            || zonesHeader.waitForExistence(timeout: 2)
            || channelsHeader.waitForExistence(timeout: 2)
        XCTAssertTrue(hasChannelContent, "Channel content should be displayed after navigation")
    }

    // MARK: - Channel Frequency Editing

    func testNavigateToGeneralSettings() {
        selectSidebarCategory("general")

        // General settings should be displayed
        // The FormEditorView or GeneralSettingsView should appear
        // Wait for any settings content to load
        let settingsExist = app.staticTexts["Device Information"].firstMatch.waitForExistence(timeout: 3)
            || app.groups.firstMatch.waitForExistence(timeout: 2)
        // For raw codeplug models, the FormEditorView renders settings as a form
        XCTAssertTrue(settingsExist || app.scrollViews.firstMatch.waitForExistence(timeout: 2),
                      "General settings content should be visible")
    }

    // MARK: - Toolbar State

    func testToolbarButtonsExistInEditingPhase() {
        XCTAssertTrue(readButton.waitForExistence(timeout: 3), "Read button should exist in toolbar")
        XCTAssertTrue(writeButton.waitForExistence(timeout: 3), "Write button should exist in toolbar")
        XCTAssertTrue(cloneButton.waitForExistence(timeout: 3), "Clone button should exist in toolbar")
    }

    func testReadButtonDisabledWithoutRadio() {
        // Without a connected radio, Read should be disabled
        XCTAssertTrue(readButton.waitForExistence(timeout: 3))
        XCTAssertFalse(readButton.isEnabled, "Read button should be disabled without a connected radio")
    }

    func testWriteButtonDisabledWithoutRadio() {
        // Without a connected radio, Write should be disabled
        XCTAssertTrue(writeButton.waitForExistence(timeout: 3))
        // Write is disabled when no radio is detected (detectedDevices.isEmpty)
        XCTAssertFalse(writeButton.isEnabled, "Write button should be disabled without a connected radio")
    }
}
