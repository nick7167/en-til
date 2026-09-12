import XCTest

final class EnTilUITests: XCTestCase {
    @MainActor func testHomeAndKeyboard() throws {
        let app = launch("home")
        XCTAssertTrue(app.buttons["Opret spil"].waitForExistence(timeout: 5))
        app.buttons["Deltag i spil"].tap()
        let code = app.textFields.firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: 3))
        code.tap()
        dismissKeyboardTutorial(app)
        code.typeText("k7mx")
        XCTAssertEqual(code.value as? String, "K7MX")
        XCTAssertTrue(app.buttons["Find spil"].isEnabled)
        XCTAssertTrue(app.buttons["Find spil"].isHittable)
        attach(app, "keyboard-uppercase-K7MX")
        app.terminate()
    }

    @MainActor func testAllApprovedReferenceScreens() throws {
        // Sheet position is the stable screenshot name; routes are DEBUG only.
        let screens: [(String, String, String)] = [
            ("A01-home", "home", "Opret spil"),
            ("A02-lobby", "lobby", "Dit spil"),
            ("A03-question", "answer", "Hvilken planet er størst i solsystemet?"),
            ("A04-backing", "backing", "Hvem satser du på?"),
            ("A05-board", "board", "Sådan står I"),
            ("A06-shop", "shop", "Mere på spil"),
            ("B01-code", "join", "Find spil"),
            ("B02-name", "name", "Hvad skal vi kalde dig?"),
            ("B03-characters", "characters", "Find din figur"),
            ("B04-guest-lobby", "guest-lobby", "Vi samler holdet"),
            ("C01-setup", "setup", "Spilindstillinger"),
            ("C02-pack-selection", "pack-selection", "Vælg pakker"),
            ("C03-pack-detail", "pack-detail", "Isbryderen"),
            ("C04-bundle", "bundle", "Alle seks pakker"),
            ("D01-private", "private", "Spring over"),
            ("D02-private-waiting", "private-waiting", "Dit svar er låst"),
            ("D03-guess", "guess", "Hvor mange svarede ja?"),
            ("D04-personal-reveal", "personal-reveal", "Så mange svarede ja"),
            ("E01-code-error", "code-error", "Prøv igen"),
            ("E02-reconnect", "reconnect", "Forbindelsen blev afbrudt"),
            ("E03-paused", "paused", "Vi mangler en spiller"),
            ("E04-finale", "finale", "Freja vinder!"),
            ("F01-settings", "settings", "Indstillinger"),
            ("F02-adult", "adult", "Er du fyldt 18 år?"),
            ("F03-results", "results", "Rundens resultat"),
            ("F04-pack-owned", "pack-owned", "Pakken er din")
        ]
        for (attachmentName, route, expected) in screens {
            let app = launch(route)
            let marker = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", expected)).firstMatch
            XCTAssertTrue(marker.waitForExistence(timeout: 8), "Missing \(expected) on \(route)")
            XCTAssertFalse(app.staticTexts["Skærmeksemplet kunne ikke indlæses."].exists)
            if ["join", "name", "code-error"].contains(route) { dismissKeyboardTutorial(app) }
            if route == "answer" {
                for answer in ["Jorden", "Mars", "Jupiter", "Saturn"] { XCTAssertTrue(app.buttons[answer].exists, answer) }
            }
            if route == "answer" { app.buttons["Saturn"].tap() }
            if route == "private" { app.buttons["Ja"].tap() }
            if route == "guess" {
                for number in 0...4 { XCTAssertTrue(app.buttons["guess-\(number)"].isHittable) }
                app.buttons["guess-2"].tap()
                XCTAssertTrue(app.buttons["Lås dit gæt"].isEnabled)
            }
            if route == "board" {
                let position = app.otherElements["board-own-position"]
                XCTAssertTrue(position.waitForExistence(timeout: 5))
                XCTAssertTrue(position.isHittable)
            }
            if route == "personal-reveal" { XCTAssertTrue(app.staticTexts["2 af 4"].exists) }
            attach(app, attachmentName)
            app.terminate()
        }
    }

    @MainActor func testAdditionalServerSnapshotScreens() throws {
        for (route, text) in [("waiting", "Vi venter på de sidste …"), ("reveal", "Det rigtige svar"), ("away", "Du sidder over"), ("late", "Du er med næste gang"), ("eight-lobby", "Dit spil"), ("eight-backing", "Hvem satser du på?")] {
            let app = launch(route)
            XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 5))
            if route == "eight-backing" {
                let lastFriend = app.buttons["back-p7"]
                XCTAssertTrue(lastFriend.isHittable)
                lastFriend.tap()
                XCTAssertTrue(app.buttons["Sats på Oscar"].isHittable)
            }
            if route == "eight-lobby" {
                if !app.buttons["Start spil"].isHittable { app.swipeUp() }
                XCTAssertTrue(app.buttons["Start spil"].isHittable)
            }
            attach(app, "extra-\(route)")
            app.terminate()
        }
    }

    @MainActor func testLargeTextLayouts() throws {
        for (route, action) in [("home", "Opret spil"), ("board", "Klar til næste runde"), ("eight-backing", "back-p7")] {
            let app = launch(route, largeText: true)
            let button = app.buttons[action]
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5))
            for _ in 0..<6 {
                if button.exists && button.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(button.exists && button.isHittable, "Large text action: \(route)")
            attach(app, "large-text-\(route)")
            app.terminate()
        }
    }

    @MainActor private func launch(_ route: String, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ENTIL_SCREENSHOT_FIXTURE"] = route
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }

    @MainActor private func dismissKeyboardTutorial(_ app: XCUIApplication) {
        // Only dismiss a first-use keyboard notice, never an arbitrary app Continue button.
        let notices = ["Speed up your typing", "QuickPath", "Skriv hurtigere"]
        guard notices.contains(where: { app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", $0)).firstMatch.exists }) else { return }
        for title in ["Continue", "Fortsæt"] {
            let button = app.buttons[title]
            if button.exists && button.isHittable { button.tap(); return }
        }
    }

    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
