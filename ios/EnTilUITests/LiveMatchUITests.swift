import XCTest
import Foundation

/// Runs against the real local Worker. Catalogue answers stay in the test bundle.
@MainActor final class LiveMatchUITests: XCTestCase {
    private struct Guest { let id: String; let token: String }
    private var room: [String: Any] = [:]
    private var roomID = ""

    func testLiveMatchReopenAndRematch() async throws {
        let host = try await guest()
        let friend = try await guest()
        let created = try await call("/v1/rooms", token: host.token, body: envelope([
            "type": "join", "name": "Freja", "character": 1, "adult": false, "drinking": false
        ]))
        room = try XCTUnwrap(created["snapshot"] as? [String: Any])
        roomID = try XCTUnwrap(room["roomID"] as? String)
        let code = try XCTUnwrap(room["code"] as? String)
        try await command(["type": "join", "name": "Noah", "character": 2, "adult": false, "drinking": false], by: friend)
        try await command(["type": "settings", "settings": ["finish": 5, "timed": false, "answerSeconds": 20, "backingSeconds": 10, "drinking": false, "packs": ["free"]]], by: host)

        let app = XCUIApplication()
        app.launchArguments = ["-name", "Alma", "-character", "3"]
        app.launch()
        try tap(app.buttons["Deltag i spil"], in: app)
        let codeField = app.textFields.firstMatch
        XCTAssertTrue(codeField.waitForExistence(timeout: 5))
        codeField.tap()
        let notices = ["Speed up your typing", "QuickPath", "Skriv hurtigere"]
        if notices.contains(where: { app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", $0)).firstMatch.exists }) {
            for title in ["Continue", "Fortsæt"] where app.buttons[title].exists && app.buttons[title].isHittable {
                app.buttons[title].tap()
                break
            }
        }
        codeField.typeText(code.lowercased())
        try tap(app.buttons["Find spil"], in: app)
        try tap(app.buttons["Vælg figur"], in: app)
        try tap(app.buttons["Deltag i spil"], in: app)
        XCTAssertTrue(app.staticTexts["Vi samler holdet"].waitForExistence(timeout: 10))
        try tap(app.buttons["Jeg er klar"], in: app)
        XCTAssertTrue(app.buttons["Jeg er ikke klar endnu"].waitForExistence(timeout: 5))
        try await command(["type": "ready", "value": true], by: friend)
        try await command(["type": "start"], by: host)

        let catalogueURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "catalogue.draft", withExtension: "json"))
        let catalogue = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: catalogueURL)) as? [String: Any])
        let questions = try XCTUnwrap(catalogue["questions"] as? [[String: Any]])
        for number in 1...3 {
            try await waitForPhase(["private", "answer"], by: host)
            let round = try XCTUnwrap(room["round"] as? [String: Any])
            XCTAssertEqual(round["number"] as? Int, number)
            XCTAssertTrue(round["correct"] is NSNull)
            let personal = round["kind"] as? String == "personal"
            if personal {
                try tap(app.buttons["Ja"], in: app)
                try tap(app.buttons["Lås dit svar"], in: app)
                XCTAssertTrue(app.staticTexts["Dit svar er låst"].waitForExistence(timeout: 5))
                try await command(["type": "private", "value": "yes"], by: host)
                try await command(["type": "private", "value": "yes"], by: friend)
            }
            let question = try XCTUnwrap(questions.first { $0["id"] as? String == round["questionID"] as? String })
            let answer = try (personal ? 3 : XCTUnwrap(question["correct"] as? Int))
            if personal {
                try tap(app.buttons["guess-3"], in: app)
            } else {
                let options = try XCTUnwrap(round["options"] as? [String])
                try tap(app.buttons[options[answer]], in: app)
            }
            try tap(app.buttons[personal ? "Lås dit gæt" : "Lås dit svar"], in: app)
            try tap(app.buttons["back-\(host.id)"], in: app)
            try tap(app.buttons["Sats på Freja"], in: app)
            XCTAssertTrue(app.staticTexts["1 har valgt færdigt"].waitForExistence(timeout: 5))
            for participant in [host, friend] {
                try await command(["type": "answer", "value": answer], by: participant)
                try await command(["type": "back", "playerID": participant.id == host.id ? friend.id : host.id], by: participant)
            }
            XCTAssertEqual(room["phase"] as? String, "reveal")
            try await waitForPhase([number == 3 ? "finale" : "board"], by: host)
            let results = try XCTUnwrap((room["round"] as? [String: Any])?["results"] as? [[String: Any]])
            XCTAssertEqual(results.count, 3)
            XCTAssertTrue(results.allSatisfy { $0["points"] as? Int == 2 })
            if number < 3 {
                XCTAssertTrue(app.staticTexts["Sådan står I"].waitForExistence(timeout: 10))
                if number == 1 {
                    app.terminate()
                    app.launch()
                    XCTAssertTrue(app.staticTexts["Sådan står I"].waitForExistence(timeout: 10))
                }
                try tap(app.buttons["Klar til næste runde"], in: app)
                XCTAssertTrue(app.buttons["Vent, jeg er ikke klar"].waitForExistence(timeout: 5))
                try await command(["type": "ready", "value": true], by: host)
                try await command(["type": "ready", "value": true], by: friend)
            }
        }
        XCTAssertTrue(app.staticTexts["I deler sejren!"].waitForExistence(timeout: 10))
        XCTAssertEqual((room["winners"] as? [String])?.count, 3)
        XCTAssertTrue((room["players"] as? [[String: Any]])?.allSatisfy { $0["score"] as? Int == 6 } == true)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "live-joint-finale"; capture.lifetime = .keepAlways; add(capture)
        try await command(["type": "rematch"], by: host)
        XCTAssertEqual(room["code"] as? String, code)
        XCTAssertTrue(app.staticTexts["Vi samler holdet"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Kopiér spilkode \(code)"].exists)
        try tap(app.buttons["Forlad"], in: app)
        try tap(app.buttons["Forlad spillet"], in: app)
        XCTAssertTrue(app.buttons["Opret spil"].waitForExistence(timeout: 10))
        try tap(app.buttons["Tilbage til dit spil"], in: app)
        XCTAssertTrue(app.staticTexts["Vi samler holdet"].waitForExistence(timeout: 10))
        room = try await call("/v1/rooms/\(roomID)", token: host.token)
        XCTAssertEqual((room["players"] as? [[String: Any]])?.count, 3)
        app.terminate()
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication) throws {
        guard element.waitForExistence(timeout: 10) else {
            XCTFail("Missing live control")
            throw NSError(domain: "LiveMatchUITests", code: 1)
        }
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isEnabled)
        element.tap()
    }
    private func guest() async throws -> Guest {
        let data = try await call("/v1/sessions", body: [:])
        return Guest(id: try XCTUnwrap(data["id"] as? String), token: try XCTUnwrap(data["token"] as? String))
    }
    private func envelope(_ action: [String: Any]) -> [String: Any] {
        ["v": 1, "requestID": UUID().uuidString, "matchID": room["matchID"] ?? NSNull(),
         "roundID": (room["round"] as? [String: Any])?["id"] ?? NSNull(), "action": action]
    }
    private func command(_ action: [String: Any], by guest: Guest) async throws {
        let ack = try await call("/v1/rooms/\(roomID)/commands", token: guest.token, body: envelope(action))
        room = try XCTUnwrap(ack["snapshot"] as? [String: Any])
    }
    private func waitForPhase(_ phases: Set<String>, by guest: Guest) async throws {
        let deadline = Date().addingTimeInterval(20)
        repeat {
            room = try await call("/v1/rooms/\(roomID)", token: guest.token)
            if let phase = room["phase"] as? String, phases.contains(phase) { return }
            try await Task.sleep(for: .seconds(2))
        } while Date() < deadline
        XCTFail("Server did not reach \(phases); current phase: \(room["phase"] ?? "missing")")
        throw NSError(domain: "LiveMatchUITests", code: 2)
    }
    private func call(_ path: String, token: String? = nil, body: [String: Any]? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8787" + path)!)
        request.httpMethod = body == nil ? "GET" : "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = try XCTUnwrap(response as? HTTPURLResponse).statusCode
        guard (200...299).contains(status) else {
            XCTFail("Local API \(path) returned \(status): \(String(decoding: data, as: UTF8.self))")
            throw NSError(domain: "LiveMatchUITests", code: status)
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
