import XCTest

/// Tests for radio read/write workflows.
///
/// Since UI tests cannot connect to real hardware, these tests verify the UI flow
/// when no radio is connected (button states, error handling, sheet presentation).
/// Full integration tests with mock hardware belong in the package-level test suites.
final class RadioCommunicationTests: CPSAppUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        assertWelcomeScreenVisible()
    }

    // MARK: - Read from Radio

    func testReadButtonOnWelcomeRequiresRadio() {
        // The "Read from Radio" button should not appear without a detected radio
        let readRadioButton = app.buttons["welcome.readRadio"]
        // Without a radio connected, this button shouldn't appear
        XCTAssertFalse(readRadioButton.exists,
                       "Read from Radio button should not appear without a detected radio")
    }

    func testNoRadioDetectedSectionVisible() {
        // When no radio is connected, the help section should show
        let noRadioText = app.staticTexts["No Radio Detected"]
        XCTAssertTrue(noRadioText.waitForExistence(timeout: 3),
                      "No Radio Detected section should be visible")
    }

    // MARK: - Write to Radio with Validation

    func testWriteButtonDisabledInEditingWithoutRadio() {
        createNewProfile(modelID: "clp1010")
        XCTAssertTrue(isEditingPhaseActive())

        let write = app.buttons["toolbar.write"]
        XCTAssertTrue(write.waitForExistence(timeout: 3))
        XCTAssertFalse(write.isEnabled,
                       "Write button should be disabled when no radio is connected")
    }

    func testReadButtonDisabledInEditingWithoutRadio() {
        createNewProfile(modelID: "clp1010")
        XCTAssertTrue(isEditingPhaseActive())

        let read = app.buttons["toolbar.read"]
        XCTAssertTrue(read.waitForExistence(timeout: 3))
        XCTAssertFalse(read.isEnabled,
                       "Read button should be disabled when no radio is connected")
    }

    // MARK: - Radio Status Indicator

    func testRadioStatusIndicatorShowsNoRadio() {
        createNewProfile(modelID: "clp1010")
        XCTAssertTrue(isEditingPhaseActive())

        // The status indicator should show "No Radio" or similar text
        let noRadioLabel = app.staticTexts["No Radio"]
        XCTAssertTrue(noRadioLabel.waitForExistence(timeout: 3),
                      "Radio status should indicate no radio detected")
    }
}
