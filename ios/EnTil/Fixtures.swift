#if DEBUG
import Foundation
extension GameClient {
    func loadFixture(_ name: String) {
        UserDefaults.standard.set("Nicklas", forKey: "name")
        guard name != "home" else { return }
        let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") ?? Bundle.main.url(forResource: name, withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url), let snapshot = try? JSONDecoder().decode(RoomSnapshot.self, from: data) else {
            problem = "Skærmeksemplet kunne ikke indlæses."; return
        }
        room = snapshot
        setFixtureClock(snapshot.serverTime)
    }
}
#endif
