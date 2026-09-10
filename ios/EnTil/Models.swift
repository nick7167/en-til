import Foundation

struct GameSettings: Codable, Equatable, Sendable {
    var finish = 20
    var timed = true
    var answerSeconds = 20
    var backingSeconds = 10
    var drinking = false
    var packs = ["free"]
}
struct Seat: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let character: Int
    let connected: Bool
    let away: Bool
    let late: Bool
    let ready: Bool
    let score: Int
    let complete: Bool
}
struct RoundResult: Codable, Identifiable, Sendable {
    var id: String { playerID }
    let playerID: String
    let answer: Int?
    let back: String?
    let own: Int
    let backing: Int
    let points: Int
    let score: Int
    let sips: Int?
}
struct RoundSnapshot: Codable, Identifiable, Sendable {
    let id: String
    let number: Int
    let questionID: String
    let kind: String
    let pack: String
    let prompt: String
    let options: [String]
    let responseCount: Int?
    let deadline: Double?
    let privateLocked: Bool
    let answerLocked: Bool
    let backLocked: Bool
    let ownAnswer: Int?
    let correct: Int?
    let fact: String?
    let source: String?
    let revealAt: Double?
    let revealStage: Int
    let results: [RoundResult]
}
struct Reaction: Codable, Sendable { let playerID: String; let value: String; let at: Double }
struct RoomSnapshot: Codable, Sendable {
    let v: Int
    let roomID: String
    let code: String
    let hostID: String
    let me: String
    let serverTime: Double
    let phase: String
    let matchID: String?
    let settings: GameSettings
    let adultRequired: Bool
    let contentVersion: String
    let players: [Seat]
    let round: RoundSnapshot?
    let countdownAt: Double?
    let winners: [String]
    let reactions: [Reaction]
    let fallbackNotice: Bool
    var ownSeat: Seat? { players.first { $0.id == me } }
    var isHost: Bool { me == hostID }
}
struct GuestSession: Codable, Sendable { let v: Int; let id: String; let token: String }
struct CommandAction: Encodable, Sendable {
    let type: String
    var name: String?
    var character: Int?
    var adult: Bool?
    var drinking: Bool?
    var settings: GameSettings?
    var value: CommandValue?
    var playerID: String?
    var connected: Bool?
}
enum CommandValue: Encodable, Sendable {
    case bool(Bool), number(Int), text(String)
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .text(let value): try container.encode(value)
        }
    }
}
struct GameCommand: Encodable, Sendable {
    let v = 1
    let requestID: String
    let matchID: String?
    let roundID: String?
    let action: CommandAction
    init(room: RoomSnapshot?, action: CommandAction) {
        requestID = UUID().uuidString.lowercased()
        matchID = room?.matchID; roundID = room?.round?.id; self.action = action
    }
    // Null identities are required by the versioned wire contract, not omitted.
    enum CodingKeys: String, CodingKey { case v, requestID, matchID, roundID, action }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(v, forKey: .v); try c.encode(requestID, forKey: .requestID)
        try c.encode(matchID, forKey: .matchID); try c.encode(roundID, forKey: .roundID)
        try c.encode(action, forKey: .action)
    }
}
struct Acknowledgement: Decodable { let requestID: String; let snapshot: RoomSnapshot? }
struct ServerMessage: Decodable { let type: String; let snapshot: RoomSnapshot?; let code: String?; let message: String? }
struct APIProblem: Decodable, Error, LocalizedError { let code: String; let message: String; var errorDescription: String? { message } }

struct Pack: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let intensity: String?
    let symbol: String
    let color: UInt
    var adult: Bool { ["lidt-for-aerlig", "efter-midnat", "uden-filter"].contains(id) }
    static let all: [Pack] = [
        .init(id: "free", title: "Gratis mix", subtitle: "Perfekt til at komme i gang.", intensity: nil, symbol: "sparkles", color: 0x9580D7),
        .init(id: "danmark", title: "Danmark", subtitle: "Fra Skagen til Sønderjylland — og alt derimellem.", intensity: nil, symbol: "flag.fill", color: 0xEB756E),
        .init(id: "film-tv", title: "Film & TV", subtitle: "Ikoniske scener. Store replikker. Små detaljer.", intensity: nil, symbol: "movieclapper.fill", color: 0x7E87D3),
        .init(id: "isbryderen", title: "Isbryderen", subtitle: "Små vaner. Store afsløringer. Find ud af, hvor meget I har til fælles.", intensity: "Let", symbol: "mountain.2.fill", color: 0x8CBBED),
        .init(id: "lidt-for-aerlig", title: "Lidt for ærlig", subtitle: "Tør du svare ærligt?", intensity: "Personlig", symbol: "heart.fill", color: 0xE98DB4),
        .init(id: "efter-midnat", title: "Efter midnat", subtitle: "Når samtalen bliver vildere.", intensity: "Fræk", symbol: "moon.stars.fill", color: 0x9581CC),
        .init(id: "uden-filter", title: "Uden filter", subtitle: "Ingen pæne svar her.", intensity: "Meget fræk", symbol: "sun.max.fill", color: 0xFFBC6B)
    ]
}

struct JoinPreview: Decodable, Sendable {
    struct Occupant: Decodable, Sendable { let name: String; let character: Int }
    let roomID: String
    let code: String
    let characters: [Occupant]
    let adultRequired: Bool
    var seats: [Seat] { characters.map { Seat(id: "preview-\($0.character)", name: $0.name, character: $0.character, connected: true, away: false, late: false, ready: false, score: 0, complete: false) } }
}
