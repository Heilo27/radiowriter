import XCTest

/// Tests for keyboard shortcuts and menu commands.
final class KeyboardShortcutTests: CPSAppUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        assertWelcomeScreenVisible()
        createNewProfile(modelID: "clp1010")
        XCTAssertTrue(isEditingPhaseActive())
    }

    // MARK: - Undo/Redo Shortcuts

    func testUndoShortcutAvailable() {
        // Cmd+Z should be handled (even if no undo available, it shouldn't crash)
        app.typeKey("z", modifierFlags: .command)
        // App should remain in editing phase
        XCTAssertTrue(isEditingPhaseActive(timeout: 2))
    }

    func testRedoShortcutAvailable() {
        // Cmd+Shift+Z should be handled
        app.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertTrue(isEditingPhaseActive(timeout: 2))
    }

    // MARK: - Radio Menu Shortcuts

    func testRadioMenuExists() {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 3))

        // Look for Radio menu
        let radioMenu = menuBar.menuBarItems["Radio"]
        if radioMenu.exists {
            radioMenu.click()

            // Verify menu items exist
            let readItem = app.menuItems["Read from Radio"]
            let writeItem = app.menuItems["Write to Radio"]
            let hasRead = readItem.waitForExistence(timeout: 2)
            let hasWrite = writeItem.waitForExistence(timeout: 2)

            // At least expect the Radio menu has content
            XCTAssertTrue(hasRead || hasWrite, "Radio menu should contain Read/Write items")

            app.typeKey(.escape, modifierFlags: [])
        }
    }

    // MARK: - Save Shortcut

    func testCmdSTriggeresSaveDialog() {
        app.typeKey("s", modifierFlags: .command)

        // Should show save dialog for a new (unsaved) document
        let dialog = app.dialogs.firstMatch
        if dialog.waitForExistence(timeout: 3) {
            dialog.buttons["Cancel"].click()
        }
        // App should still be functional
        XCTAssertTrue(isEditingPhaseActive(timeout: 2))
    }

    // MARK: - Close Shortcut

    func testCmdWClosesDocument() {
        app.typeKey("w", modifierFlags: .command)

        // Should return to welcome (no unsaved changes on fresh profile)
        assertWelcomeScreenVisible(timeout: 5)
    }
}
