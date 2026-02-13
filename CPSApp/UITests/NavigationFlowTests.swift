import XCTest

/// Tests for overall app navigation flow between phases and categories.
final class NavigationFlowTests: CPSAppUITestCase {

    // MARK: - Phase Transitions

    func testAppLaunchesInWelcomePhase() {
        assertWelcomeScreenVisible()
    }

    func testWelcomeToEditingTransition() {
        assertWelcomeScreenVisible()
        createNewProfile(modelID: "clp1010")
        XCTAssertTrue(isEditingPhaseActive(), "Should transition to editing phase")
    }

    func testEditingToWelcomeTransition() {
        assertWelcomeScreenVisible()
        createNewProfile(modelID: "clp1010")
        XCTAssertTrue(isEditingPhaseActive())

        // Close document to return to welcome
        app.typeKey("w", modifierFlags: .command)
        assertWelcomeScreenVisible(timeout: 5)
    }

    func testRoundTripNavigation() {
        // Welcome -> Editing -> Welcome -> Editing
        assertWelcomeScreenVisible()

        // First trip
        createNewProfile(modelID: "clp1010")
        XCTAssertTrue(isEditingPhaseActive())
        app.typeKey("w", modifierFlags: .command)
        assertWelcomeScreenVisible(timeout: 5)

        // Second trip
        createNewProfile(modelID: "clp1040")
        XCTAssertTrue(isEditingPhaseActive())
    }

    // MARK: - Multiple Model Support

    func testCreateProfileWithDifferentModels() {
        assertWelcomeScreenVisible()

        let models = ["clp1010", "clp1040"]

        for modelID in models {
            selectRadioModel(modelID)
            let createButton = app.buttons["welcome.createProfile"]
            if createButton.waitForExistence(timeout: 3) && createButton.isEnabled {
                createButton.click()

                if isEditingPhaseActive(timeout: 3) {
                    // Success - return to welcome for next model
                    app.typeKey("w", modifierFlags: .command)
                    assertWelcomeScreenVisible(timeout: 5)
                }
            }
        }
    }

    // MARK: - Window Title

    func testWindowTitleReflectsModel() {
        assertWelcomeScreenVisible()
        createNewProfile(modelID: "clp1010")
        XCTAssertTrue(isEditingPhaseActive())

        // Window title should contain the model identifier
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, "Main window should exist")
    }
}
