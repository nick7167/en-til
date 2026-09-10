import Foundation
import Observation

@MainActor @Observable final class GameClient {
    var room: RoomSnapshot?
    var busy = false
    var reconnecting = false
    var problem: String?
    var needsAdult = false
    var joinPreview: JoinPreview?
    var ageDeclined = false
    var owned: Set<String> = []
    private(set) var clockOffset: Double = 0
    private var session: GuestSession?
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var pendingJoin: (String, CommandAction)?
    private var pendingCommand: (String, GameCommand)?
    private let base: URL
    init() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "EnTilAPIURL") as? String ?? "https://unconfigured.invalid"
        base = URL(string: configured) ?? URL(string: "https://unconfigured.invalid")!
    }
    #if DEBUG
    func setFixtureClock(_ milliseconds: Double) { clockOffset = milliseconds - Date().timeIntervalSince1970 * 1000 }
    #endif
    var serverNow: Double { Date().timeIntervalSince1970 * 1000 + clockOffset }
    func ensureSession() async throws {
        if session != nil { return }
        if let saved = try SessionStore.load() { session = saved; return }
        let created: GuestSession = try await request("v1/sessions", method: "POST", data: Data("{}".utf8), authenticated: false)
        try SessionStore.save(created); session = created
    }
    func create(name: String, character: Int, adult: Bool, drinking: Bool) async {
        await perform {
            try await self.ensureSession()
            let action = CommandAction(type: "join", name: name, character: character, adult: adult, drinking: drinking)
            let command = GameCommand(room: nil, action: action)
            let ack: Acknowledgement = try await self.sendReliable("v1/rooms", command: command)
            self.accept(ack.snapshot); self.connect()
            if adult && UserDefaults.standard.bool(forKey: "hostDrinking"), let room = self.room {
                var settings = room.settings; settings.drinking = true
                let saved: Acknowledgement = try await self.sendReliable("v1/rooms/\(room.roomID)/commands", command: GameCommand(room: room, action: .init(type: "settings", settings: settings)))
                self.accept(saved.snapshot)
            }
        }
    }
    func findRoom(code: String) async -> Bool {
        guard !busy else { return false }; busy = true; problem = nil
        defer { busy = false }
        do {
            try await ensureSession()
            let preview: JoinPreview = try await request("v1/lookup", method: "POST", data: JSONEncoder().encode(["code": code]))
            joinPreview = preview
            return true
        } catch { problem = error.localizedDescription; return false }
    }
    func join(code: String, name: String, character: Int, adult: Bool, drinking: Bool) async {
        await perform {
            try await self.ensureSession()
            struct Lookup: Decodable { let roomID: String }
            let lookup: Lookup = try await self.request("v1/lookup", method: "POST", data: JSONEncoder().encode(["code": code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)]))
            let action = CommandAction(type: "join", name: name, character: character, adult: adult, drinking: drinking)
            self.pendingJoin = (lookup.roomID, action)
            let ack: Acknowledgement = try await self.sendReliable("v1/rooms/\(lookup.roomID)/commands", command: GameCommand(room: nil, action: action))
            self.pendingJoin = nil; self.accept(ack.snapshot); self.connect()
        }
    }
    func confirmAdult() async {
        UserDefaults.standard.set(true, forKey: "adult")
        needsAdult = false
        if let (id, action) = pendingJoin {
            var confirmed = action; confirmed.adult = true
            await perform {
                let ack: Acknowledgement = try await self.sendReliable("v1/rooms/\(id)/commands", command: GameCommand(room: nil, action: confirmed))
                self.pendingJoin = nil; self.accept(ack.snapshot); self.connect()
            }
        } else { await command(CommandAction(type: "adult", value: .bool(true))) }
    }
    func declineAdult() async {
        needsAdult = false; pendingJoin = nil; ageDeclined = true
        if room != nil { await leave() }
    }
    func command(_ action: CommandAction) async {
        guard let room else { return }
        await perform {
            let ack: Acknowledgement = try await self.sendReliable("v1/rooms/\(room.roomID)/commands", command: GameCommand(room: room, action: action))
            self.accept(ack.snapshot)
        }
    }
    func restoreSeat() async {
        guard let id = UserDefaults.standard.string(forKey: "roomID") else { return }
        await perform {
            try await self.ensureSession()
            let snapshot: RoomSnapshot = try await self.request("v1/rooms/\(id)")
            self.accept(snapshot); self.connect()
        }
    }
    func leave() async {
        guard let current = room else { return }
        await perform {
            let _: Acknowledgement = try await self.sendReliable("v1/rooms/\(current.roomID)/commands", command: GameCommand(room: current, action: .init(type: "leave")))
            self.disconnect(); self.room = nil
            // Internal room ID is retained: a deliberate leave preserves the seat.
        }
    }
    func refreshOwnership() async throws {
        try await ensureSession()
        struct Ownership: Decodable { let owned: [String] }
        let response: Ownership = try await request("v1/ownership")
        owned = Set(response.owned)
    }
    func verifyPurchase(_ jws: String) async throws {
        try await ensureSession()
        struct Verified: Decodable { let verified: Bool }
        let _: Verified = try await request("v1/purchases", method: "POST", data: JSONEncoder().encode(["jws": jws]))
        try await refreshOwnership()
    }
    func report(reason: String, note: String) async {
        guard let room else { return }
        await perform {
            struct Received: Decodable { let received: Bool }
            let _: Received = try await self.request("v1/rooms/\(room.roomID)/reports", method: "POST", data: JSONEncoder().encode(["id": UUID().uuidString.lowercased(), "reason": reason, "note": note]))
        }
    }
    private func perform(_ operation: () async throws -> Void) async {
        guard !busy else { return }; busy = true; problem = nil
        defer { busy = false }
        do { try await operation() }
        catch let error as APIProblem where error.code == "adult_required" { needsAdult = true }
        catch { problem = error.localizedDescription }
    }
    private func sendReliable(_ path: String, command: GameCommand) async throws -> Acknowledgement {
        // The same request ID is retried after transport failures. Never manufacture another answer.
        pendingCommand = (path, command)
        var lastError: (any Error)?
        for attempt in 0..<3 {
            do {
                let ack: Acknowledgement = try await request(path, method: "POST", data: JSONEncoder().encode(command))
                pendingCommand = nil; return ack
            } catch let error as APIProblem { pendingCommand = nil; throw error }
            catch { lastError = error; if attempt < 2 { try await Task.sleep(for: .milliseconds(400 * (attempt + 1))) } }
        }
        throw lastError ?? URLError(.networkConnectionLost)
    }
    private func request<T: Decodable>(_ path: String, method: String = "GET", data: Data? = nil, authenticated: Bool = true) async throws -> T {
        var request = URLRequest(url: base.appending(path: path)); request.httpMethod = method; request.httpBody = data
        request.timeoutInterval = 12; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated, let session { request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw (try? JSONDecoder().decode(APIProblem.self, from: data)) ?? APIProblem(code: "unavailable", message: "Vi kunne ikke få forbindelse. Prøv igen.")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    private func accept(_ snapshot: RoomSnapshot?) {
        guard let snapshot else { return }
        if let room, snapshot.roomID == room.roomID, snapshot.serverTime < room.serverTime { return }
        clockOffset = snapshot.serverTime - Date().timeIntervalSince1970 * 1000
        room = snapshot; needsAdult = snapshot.adultRequired
        UserDefaults.standard.set(snapshot.roomID, forKey: "roomID")
    }
    func connect() {
        guard let room, let session else { return }
        disconnect(); reconnecting = true
        var components = URLComponents(url: base.appending(path: "v1/rooms/\(room.roomID)/socket"), resolvingAgainstBaseURL: false)
        components?.scheme = base.scheme == "http" ? "ws" : "wss"
        guard let url = components?.url else { return }
        var request = URLRequest(url: url); request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        let socket = URLSession.shared.webSocketTask(with: request); self.socket = socket; socket.resume()
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await socket.receive()
                    let data: Data
                    switch message { case .data(let bytes): data = bytes; case .string(let text): if text == "pong" { continue }; data = Data(text.utf8); @unknown default: continue }
                    let envelope = try JSONDecoder().decode(ServerMessage.self, from: data)
                    self?.accept(envelope.snapshot); self?.reconnecting = false
                } catch {
                    if Task.isCancelled { return }
                    self?.reconnecting = true; self?.scheduleReconnect(); return
                }
            }
        }
        heartbeatTask = Task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(15)); try await socket.send(.string("ping")) }
                catch { return }
            }
        }
    }
    private func scheduleReconnect() {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(2))
                guard let self, let room = self.room else { return }
                let latest: RoomSnapshot = try await self.request("v1/rooms/\(room.roomID)")
                self.accept(latest)
                if let (path, pending) = self.pendingCommand {
                    let ack = try await self.sendReliable(path, command: pending); self.accept(ack.snapshot)
                }
                self.connect()
            } catch { if !Task.isCancelled { self?.scheduleReconnect() } }
        }
    }
    func disconnect() {
        receiveTask?.cancel(); heartbeatTask?.cancel(); retryTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil); socket = nil; reconnecting = false
    }
}
