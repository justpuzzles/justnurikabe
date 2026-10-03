import XCTest

/// Xcode's automated accessibility audit, one screen at a time
/// (docs/ACCESSIBILITY.md). The DEBUG screenshot scenes open each screen
/// in a known state.
@MainActor
final class AccessibilityAuditTests: XCTestCase {

    private var acceptListFalsePositives = false
    private var acceptUnattributedBoardDigits = false

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

    func testHomeAtLargestTextSize() throws {
        let app = launch(scene: "home", extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        try audit(app)
    }
}
