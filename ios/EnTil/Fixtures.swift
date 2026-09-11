#if DEBUG
import Foundation
extension GameClient {
    func loadFixture(_ name: String) {
        UserDefaults.standard.set("Nicklas", forKey: "name")
        UserDefaults.standard.set(0, forKey: "character")
        problem = nil
        room = nil
        let routesWithoutRoom: Set<String> = ["home", "join", "name", "characters", "code-error", "settings", "shop", "pack-detail", "bundle", "pack-owned"]
        guard !routesWithoutRoom.contains(name) else { return }
        let underlying = ["setup": "lobby", "pack-selection": "lobby", "results": "board", "reconnect": "answer", "adult": "lobby"][name] ?? name
        let url = Bundle.main.url(forResource: underlying, withExtension: "json", subdirectory: "Fixtures") ?? Bundle.main.url(forResource: underlying, withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url), let snapshot = try? JSONDecoder().decode(RoomSnapshot.self, from: data) else {
            problem = "Skærmeksemplet kunne ikke indlæses."; return
        }
        room = snapshot
        setFixtureClock(snapshot.serverTime)
    }
}
#endif
