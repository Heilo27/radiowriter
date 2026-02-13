import XCTest

/// Base test case for CPSApp UI tests.
/// Provides common setup, teardown, and helper methods.
class CPSAppUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigation Helpers

    /// Waits for and verifies the welcome screen is displayed.
    func assertWelcomeScreenVisible(timeout: TimeInterval = 5) {
        let newProfile = app.buttons["welcome.newProfile"]
        XCTAssertTrue(newProfile.waitForExistence(timeout: timeout), "Welcome screen should be visible")
    }

    /// Selects a radio model by its identifier in the model picker grid.
    func selectRadioModel(_ modelID: String) {
        let modelCard = app.otherElements["radioModel.\(modelID)"]
        if modelCard.waitForExistence(timeout: 3) {
            modelCard.click()
        }
    }

    /// Creates a new profile with the given model and transitions to editing.
    func createNewProfile(modelID: String) {
        selectRadioModel(modelID)
        let createButton = app.buttons["welcome.createProfile"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3))
        XCTAssertTrue(createButton.isEnabled, "Create Profile button should be enabled after selecting a model")
        createButton.click()
    }

    /// Navigates to a category in the sidebar.
    func selectSidebarCategory(_ category: String) {
        let sidebarItem = app.staticTexts["sidebar.\(category)"]
            .firstMatch
        if sidebarItem.waitForExistence(timeout: 3) {
            sidebarItem.click()
        } else {
            // Try clicking the label directly by text
            let label = app.outlines.staticTexts[category].firstMatch
            if label.waitForExistence(timeout: 2) {
                label.click()
            }
        }
    }

    /// Returns whether the editing phase (ContentView) is displayed.
    func isEditingPhaseActive(timeout: TimeInterval = 5) -> Bool {
        // The sidebar with category items indicates editing phase
        let sidebar = app.otherElements["categorySidebar"]
        return sidebar.waitForExistence(timeout: timeout)
    }

    // MARK: - Toolbar Helpers

    var readButton: XCUIElement {
        app.buttons["toolbar.read"]
    }

    var writeButton: XCUIElement {
        app.buttons["toolbar.write"]
    }

    var cloneButton: XCUIElement {
        app.buttons["toolbar.clone"]
    }

    // MARK: - Wait Helpers

    /// Waits for an element to exist with a timeout.
    @discardableResult
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }
}
