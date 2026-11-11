import XCTest

/// Xcode's automated accessibility audit, one screen at a time
/// (docs/ACCESSIBILITY.md). The DEBUG screenshot scenes open each screen
/// in a known state.
@MainActor
final class AccessibilityAuditTests: XCTestCase {

    private var acceptListFalsePositives = false
    private var acceptUnattributedBoardDigits = false
    private var acceptUnattributedContrast = false
    /// Labels whose contrast reports were measured and are false (see the test).
    private var acceptContrastOn: Set<String> = []

    private func launch(scene: String? = nil, extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetState", "-NurikabeScreenshotUnlock", "-NurikabeSeedMidPath"]
            + (scene.map { ["-NurikabeScreenshotScene", $0] } ?? []) + extra
        app.launch()
        return app
    }

    private func audit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit { issue in
            print("AUDIT | \(issue.compactDescription) | \(issue.element?.elementType.rawValue ?? 0) | \(issue.element?.label ?? "-") | \(issue.element.map { "\($0.frame)" } ?? "") | \(issue.detailedDescription)")
            // Accepted, documented in docs/ACCESSIBILITY.md: board numerals
            // (sized to cells) and the wordmark are fixed-size drawings.
            if issue.auditType == .dynamicType, let label = issue.element?.label,
               label.hasPrefix("Row ") || label.hasPrefix("Just") || label == "Nurikabe"
                || (!label.isEmpty && label.allSatisfy(\.isNumber)) { return true }
            // Progress bars (lesson steps, path progress) aren't controls.
            if issue.auditType == .hitRegion,
               issue.element?.elementType == .progressIndicator
                || issue.element?.label.hasPrefix("Step ") == true { return true }
            if self.acceptUnattributedBoardDigits, issue.element == nil, issue.auditType == .dynamicType { return true }
            if self.acceptListFalsePositives, [.dynamicType, .textClipped].contains(issue.auditType) { return true }
            if self.acceptUnattributedContrast, issue.element == nil, issue.auditType == .contrast { return true }
            if issue.auditType == .contrast, let label = issue.element?.label,
               self.acceptContrastOn.contains(label) { return true }
            return false
        }
    }

    func testHome() throws {
        let app = launch(scene: "home")
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        try audit(app)
    }

    func testBoardWithHint() throws {
        let app = launch(scene: "hint")
        XCTAssertTrue(app.otherElements["board"].waitForExistence(timeout: 20))
        let cell = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Row '")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        acceptUnattributedBoardDigits = true
        try audit(app)
    }

    func testWin() throws {
        let app = launch(scene: "win")
        XCTAssertTrue(app.otherElements["solvedCard"].waitForExistence(timeout: 20)
                      || app.staticTexts["Solved"].waitForExistence(timeout: 5))
        acceptUnattributedBoardDigits = true
        try audit(app)
    }

    func testLearnPath() throws {
        let app = launch(scene: "path")
        sleep(2)
        acceptListFalsePositives = true
        try audit(app)
    }

    func testLesson() throws {
        let app = launch(scene: "lesson")
        sleep(2)
        acceptUnattributedBoardDigits = true
        try audit(app)
    }

    func testSettings() throws {
        let app = launch(scene: "home")
        app.buttons["Settings"].tap()
        sleep(1)
        acceptListFalsePositives = true
        try audit(app)
    }

    func testStatistics() throws {
        let app = launch(scene: "home")
        app.buttons["Statistics"].tap()
        sleep(1)
        acceptListFalsePositives = true
        try audit(app)
    }

    /// 1.1: on a locked copy the 10×10 segment says "locked" in words, and
    /// the chosen difficulty is announced as selected, not only checkmarked.
    func testNewBoardSheetSpeaksLockAndSelection() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        // No screenshot scene and no unlock flag: either one unlocks the
        // app, and the 10×10 segment is only locked on a free copy.
        app.launchArguments = ["-uiTestResetState", "-NurikabeSeedMidPath"]
        app.launch()
        let tile = app.buttons["newBoardCard"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap()
        let locked = app.buttons["10×10, locked"]
        XCTAssertTrue(locked.waitForExistence(timeout: 5),
                      "segments: \(app.segmentedControls.buttons.allElementsBoundByIndex.map(\.label))")
        let steady = app.buttons["tier-\(1)"]
        XCTAssertTrue(steady.waitForExistence(timeout: 5))
        XCTAssertTrue(steady.isSelected, "the default tier is spoken as selected")
        let sharp = app.buttons["tier-\(2)"]
        XCTAssertFalse(sharp.isSelected)
        sharp.tap()
        XCTAssertTrue(sharp.isSelected)
        XCTAssertFalse(steady.isSelected)
        // A system Form: its rows and the bar's Cancel/Start report as
        // unsupported Dynamic Type / clipped with no element attached (checked
        // at AX5 by the screenshot below; docs/ACCESSIBILITY.md). Contrast
        // and hit regions stay strict.
        acceptListFalsePositives = true
        // One contrast report, on the SIZE header (Theme.textSoft over the
        // grouped background): measured from its screenshot at 7.1:1 on
        // 2026-11-08, and 7.2:1 from the colours. The audit attaches the
        // header to the report in some runs and not in others (2026-11-11:
        // attached in a full-suite run, unattached in four solo runs), so
        // both forms are accepted, and only for that header.
        acceptUnattributedContrast = true
        acceptContrastOn = ["SIZE"]
        try audit(app)
    }

    /// The sheet at the largest accessibility size, kept as an attachment so
    /// the Form's Dynamic Type reports can be judged by eye.
    func testNewBoardSheetAtLargestTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetState", "-NurikabeSeedMidPath",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let tile = app.buttons["newBoardCard"]
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap()
        XCTAssertTrue(app.buttons["tier-\(1)"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "new-board-sheet-AX5"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testHomeAtLargestTextSize() throws {
        let app = launch(scene: "home", extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        try audit(app)
    }
}
