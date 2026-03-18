import XCTest
@testable import CPSApp

final class RegulatoryWarningTests: XCTestCase {
    var warningManager: RegulatoryWarningManager!

    override func setUp() {
        super.setUp()
        warningManager = RegulatoryWarningManager()
        warningManager.resetAllWarnings()
    }

    override func tearDown() {
        warningManager.resetAllWarnings()
        super.tearDown()
    }

    func testFCCWarningInitiallyNotAcknowledged() {
        XCTAssertFalse(warningManager.fccWarningAcknowledged,
                       "FCC warning should not be acknowledged on first run")
    }

    func testFCCWarningAcknowledgement() {
        warningManager.fccWarningAcknowledged = true
        XCTAssertTrue(warningManager.fccWarningAcknowledged,
                      "FCC warning should be marked as acknowledged")
    }

    func testPreWriteWarningInitiallyNotDismissed() {
        XCTAssertFalse(warningManager.preWriteWarningDismissed,
                       "Pre-write warning should not be dismissed on first run")
    }

    func testPreWriteWarningDismissal() {
        warningManager.preWriteWarningDismissed = true
        XCTAssertTrue(warningManager.preWriteWarningDismissed,
                      "Pre-write warning should be marked as dismissed")
    }

    func testResetAllWarnings() {
        warningManager.fccWarningAcknowledged = true
        warningManager.preWriteWarningDismissed = true

        warningManager.resetAllWarnings()

        XCTAssertFalse(warningManager.fccWarningAcknowledged,
                       "FCC warning should be reset")
        XCTAssertFalse(warningManager.preWriteWarningDismissed,
                       "Pre-write warning should be reset")
    }

    func testWarningsPersistInUserDefaults() {
        let manager1 = RegulatoryWarningManager()
        manager1.fccWarningAcknowledged = true
        manager1.preWriteWarningDismissed = true

        // Create a new instance to verify persistence
        let manager2 = RegulatoryWarningManager()
        XCTAssertTrue(manager2.fccWarningAcknowledged,
                      "FCC warning acknowledgement should persist")
        XCTAssertTrue(manager2.preWriteWarningDismissed,
                      "Pre-write warning dismissal should persist")

        manager1.resetAllWarnings()
    }
}
