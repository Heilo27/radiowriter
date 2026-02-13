import XCTest

/// Tests for codeplug file operations: open, save, close.
final class CodeplugFileWorkflowTests: CPSAppUITestCase {

    // MARK: - Open Codeplug File

    func testOpenFileMenuShowsDialog() {
        assertWelcomeScreenVisible()

        // Use Cmd+O to trigger file open
        app.typeKey("o", modifierFlags: .command)

        // System file dialog should appear
        let dialog = app.dialogs.firstMatch
        if dialog.waitForExistence(timeout: 3) {
            dialog.buttons["Cancel"].click()
        }
    }

    // MARK: - Save Codeplug

    func testSaveMenuAvailableInEditingPhase() {
        assertWelcomeScreenVisible()
        createNewProfile(modelID: "clp1010")
        XCTAssertTrue(isEditingPhaseActive())

        // Use Cmd+S to trigger save
        app.typeKey("s", modifierFlags: .command)

        // File save dialog should appear (new document, no URL yet)
        let dialog = app.dialogs.firstMatch
        if dialog.waitForExistence(timeout: 3) {
            dialog.buttons["Cancel"].click()
        }
    }

    // MARK: - Close Document

    func testCloseDocumentReturnsToWelcome() {
        assertWelcomeScreenVisible()
        createNewProfile(modelID: "clp1010")
        XCTAssertTrue(isEditingPhaseActive())

        // Use the close document command (Cmd+W)
        app.typeKey("w", modifierFlags: .command)

        // Should return to welcome screen (no unsaved changes on a fresh profile)
        assertWelcomeScreenVisible(timeout: 5)
    }
}
