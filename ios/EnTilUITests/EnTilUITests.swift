import XCTest

final class EnTilUITests: XCTestCase {
    @MainActor func testHomeAndKeyboard() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ENTIL_SCREENSHOT_FIXTURE"] = "home"
        app.launch()
        XCTAssertTrue(app.buttons["Opret spil"].waitForExistence(timeout: 5))
        attach(app, "01-home")
        app.buttons["Deltag i spil"].tap()
        let code = app.textFields.firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: 3))
        code.tap(); code.typeText("k7mx")
        XCTAssertEqual(code.value as? String, "K7MX")
        XCTAssertTrue(app.buttons["Find spil"].isEnabled)
        XCTAssertTrue(app.buttons["Find spil"].isHittable)
        attach(app, "07-code-keyboard")
    }
    @MainActor func testServerSnapshotScreens() throws {
        for name in ["lobby", "answer", "backing", "waiting", "private", "guess", "reveal", "board", "finale", "away", "late"] {
            let app = XCUIApplication()
            app.launchEnvironment["ENTIL_SCREENSHOT_FIXTURE"] = name
            app.launch()
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5))
            if name == "guess" {
                for number in 0...4 {
                    XCTAssertTrue(app.buttons["guess-\(number)"].isHittable)
                }
                app.buttons["guess-2"].tap()
                XCTAssertTrue(app.buttons["Lås dit gæt"].isEnabled)
            }
            if name == "board" {
                XCTAssertTrue(app.otherElements["board-own-position"].waitForExistence(timeout: 5))
                XCTAssertTrue(app.otherElements["board-own-position"].isHittable)
            }
            attach(app, name)
            app.terminate()
        }
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
