import Testing
import Foundation
@testable import EnTil

struct ContractTests {
    @Test func initialCommandEncodesNullIdentities() throws {
        let command = GameCommand(room: nil, action: .init(type: "join", name: "Freja", character: 1, adult: false, drinking: false))
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(command)) as? [String: Any])
        #expect(object["matchID"] is NSNull)
        #expect(object["roundID"] is NSNull)
        #expect(UUID(uuidString: command.requestID) != nil)
    }
}
