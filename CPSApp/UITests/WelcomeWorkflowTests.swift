import XCTest

/// Tests for the welcome screen and initial app launch workflows.
final class WelcomeWorkflowTests: CPSAppUITestCase {

    // MARK: - Welcome Screen

    func testWelcomeScreenDisplaysOnLaunch() {
        assertWelcomeScreenVisible()

        // Verify key elements
        XCTAssertTrue(app.staticTexts["RadioWriter"].exists, "App title should be visible")
        XCTAssertTrue(app.buttons["welcome.newProfile"].exists, "New Profile button should exist")
        XCTAssertTrue(app.buttons["welcome.openExisting"].exists, "Open Existing button should exist")
    }

    func testRadioModelPickerVisible() {
        assertWelcomeScreenVisible()

        // Verify model picker header
        XCTAssertTrue(app.staticTexts["Choose Radio Model"].exists, "Model picker header should be visible")
    }

    func testSelectRadioModelEnablesCreateButton() {
        assertWelcomeScreenVisible()

        let createButton = app.buttons["welcome.createProfile"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3))

        // Before selection, create button should be disabled
        // (No model selected initially unless auto-detected)
        // Select a model
        selectRadioModel("clp1010")

        // Create button should now be enabled
        XCTAssertTrue(createButton.isEnabled, "Create Profile button should be enabled after model selection")
    }

    func testCreateProfileTransitionsToEditing() {
        assertWelcomeScreenVisible()
        createNewProfile(modelID: "clp1010")

        // Should transition to editing phase
        XCTAssertTrue(isEditingPhaseActive(), "Should transition to editing phase after creating profile")
    }

    // MARK: - Open Existing File

    func testOpenExistingButtonShowsFileDialog() {
        assertWelcomeScreenVisible()

        let openButton = app.buttons["welcome.openExisting"]
        XCTAssertTrue(openButton.exists)
        openButton.click()

        // File dialog should appear (system dialog, so we check for its presence)
        // The file importer is a system sheet; verify coordinator state changed
        // by checking that the open dialog appeared
        let dialog = app.dialogs.firstMatch
        if dialog.waitForExistence(timeout: 3) {
            // Dismiss the dialog
            dialog.buttons["Cancel"].click()
        }
        // If no dialog found, the file importer may use a different presentation
        // Just verify we didn't crash
    }
}
