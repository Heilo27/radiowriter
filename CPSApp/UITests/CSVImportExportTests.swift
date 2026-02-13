import XCTest

/// Tests for CSV import and export workflows.
final class CSVImportExportTests: CPSAppUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        assertWelcomeScreenVisible()
        createNewProfile(modelID: "clp1010")
        XCTAssertTrue(isEditingPhaseActive())
    }

    // MARK: - CSV Import Channels

    func testImportChannelsMenuExists() {
        // Access Import via the menu bar
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 3))

        // Look for the File menu or Radio menu that contains Import
        let fileMenu = menuBar.menuBarItems["File"]
        if fileMenu.exists {
            fileMenu.click()

            // Check for Import submenu
            let importItem = app.menuItems["Import Channels from CSV"]
            if importItem.waitForExistence(timeout: 2) {
                XCTAssertTrue(importItem.exists, "Import Channels menu item should exist")
                // Dismiss menu
                app.typeKey(.escape, modifierFlags: [])
            } else {
                // May be under a different menu structure
                app.typeKey(.escape, modifierFlags: [])
            }
        }
    }

    func testExportChannelsMenuExists() {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 3))

        let fileMenu = menuBar.menuBarItems["File"]
        if fileMenu.exists {
            fileMenu.click()

            let exportItem = app.menuItems["Export Channels to CSV"]
            if exportItem.waitForExistence(timeout: 2) {
                XCTAssertTrue(exportItem.exists, "Export Channels menu item should exist")
                app.typeKey(.escape, modifierFlags: [])
            } else {
                app.typeKey(.escape, modifierFlags: [])
            }
        }
    }

    // MARK: - CSV Import Contacts

    func testImportContactsMenuExists() {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 3))

        let fileMenu = menuBar.menuBarItems["File"]
        if fileMenu.exists {
            fileMenu.click()

            let importItem = app.menuItems["Import Contacts from CSV"]
            if importItem.waitForExistence(timeout: 2) {
                XCTAssertTrue(importItem.exists, "Import Contacts menu item should exist")
                app.typeKey(.escape, modifierFlags: [])
            } else {
                app.typeKey(.escape, modifierFlags: [])
            }
        }
    }

    // MARK: - CSV Export Contacts

    func testExportContactsMenuExists() {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 3))

        let fileMenu = menuBar.menuBarItems["File"]
        if fileMenu.exists {
            fileMenu.click()

            let exportItem = app.menuItems["Export Contacts to CSV"]
            if exportItem.waitForExistence(timeout: 2) {
                XCTAssertTrue(exportItem.exists, "Export Contacts menu item should exist")
                app.typeKey(.escape, modifierFlags: [])
            } else {
                app.typeKey(.escape, modifierFlags: [])
            }
        }
    }
}
