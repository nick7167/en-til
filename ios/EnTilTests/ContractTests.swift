import Testing
import Foundation
@testable import EnTil

struct ContractTests {
    @MainActor @Test func terminalRoomErrorsReleaseSeatButTransientErrorsPreserveIt() throws {
        let savedRoomID = UserDefaults.standard.object(forKey: "roomID")
        defer { UserDefaults.standard.set(savedRoomID, forKey: "roomID") }
        let url = try #require(Bundle.main.url(forResource: "lobby", withExtension: "json", subdirectory: "Fixtures") ?? Bundle.main.url(forResource: "lobby", withExtension: "json"))
        let room = try JSONDecoder().decode(RoomSnapshot.self, from: Data(contentsOf: url))
        let client = GameClient()
        for code in ["expired", "not_in_room"] {
            client.room = room; client.reconnecting = true; client.needsAdult = true
            UserDefaults.standard.set(room.roomID, forKey: "roomID")
            #expect(!client.handleTerminalRoomError(APIProblem(code: "unavailable", message: "Prøv igen.")))
            #expect(client.room?.roomID == room.roomID)
            #expect(client.reconnecting)
            #expect(UserDefaults.standard.string(forKey: "roomID") == room.roomID)
            #expect(client.handleTerminalRoomError(APIProblem(code: code, message: "Spillet er slut.")))
            #expect(client.room == nil)
            #expect(!client.reconnecting)
            #expect(!client.needsAdult)
            #expect(client.problem == "Spillet er slut.")
            #expect(UserDefaults.standard.object(forKey: "roomID") == nil)
        }
    }
    @Test func initialCommandEncodesNullIdentities() throws {
        let command = GameCommand(room: nil, action: .init(type: "join", name: "Freja", character: 1, adult: false, drinking: false))
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(command)) as? [String: Any])
        #expect(object["matchID"] is NSNull)
        #expect(object["roundID"] is NSNull)
        #expect(UUID(uuidString: command.requestID) != nil)
    }
}
