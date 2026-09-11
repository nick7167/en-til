import SwiftUI
import UIKit

struct RoomView: View {
    @Bindable var client: GameClient
    @Bindable var store: PackStore
    let room: RoomSnapshot
    let showSetup: () -> Void
    let showProfile: () -> Void
    @State private var answer: Int?
    @State private var privateAnswer: String?
    @State private var backedID: String?
    @State private var allResults = false
    @State private var report = false
    var body: some View {
        Group {
            if room.phase == "lobby" { lobby }
            else if room.ownSeat?.late == true { waitingForMatch }
            else if room.phase == "board" && room.players.filter({ !$0.away && !$0.late }).count < 3 { paused }
            else if ["board", "countdown", "finale"].contains(room.phase) { board }
            else if room.phase == "reveal" { reveal }
            else if room.ownSeat?.away == true { sittingOut }
            else { question }
        }
        .onChange(of: room.round?.id) { _, _ in answer = nil; privateAnswer = nil; backedID = nil }
        .sheet(isPresented: $allResults) { NavigationStack { ResultsView(room: room) }.presentationDragIndicator(.visible).preferredColorScheme(.dark) }
        .sheet(isPresented: $report) { NavigationStack { ReportView(client: client) }.presentationDragIndicator(.visible).preferredColorScheme(.dark) }
    }
    private var lobby: some View {
        Screen {
            Text(room.isHost ? "Dit spil" : "Vi samler holdet").font(.editorial())
            Button { UIPasteboard.general.string = room.code } label: { CodePlaque(code: room.code) }
                .buttonStyle(.plain).accessibilityLabel("Kopiér spilkode \(room.code)")
            Text("\(room.players.count) spillere").font(.caption)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 125))], spacing: 12) {
                ForEach(room.players) { seat in
                    SeatCard(seat: seat, host: seat.id == room.hostID, own: seat.id == room.me && !room.isHost, compact: room.players.count > 4)
                        .contextMenu {
                            if seat.id == room.me { Button("Rediger profil", action: showProfile) }
                            if room.isHost && seat.id != room.me { Button("Fjern spiller", role: .destructive) { Task { await client.command(.init(type: "remove", playerID: seat.id)) } } }
                        }
                }
            }
            Button(action: showSetup) {
                Panel {
                    HStack(alignment: .top) {
                        Image(systemName: "gearshape.fill").font(.title2)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(room.settings.finish) felter").font(.headline)
                            Text(room.settings.timed ? "\(room.settings.answerSeconds) sek. svar · \(room.settings.backingSeconds) sek. satsning" : "Uden tid").font(.caption)
                        }
                        Spacer(); Image(systemName: "chevron.right")
                    }
                }
            }.buttonStyle(.plain).disabled(!room.isHost)
            Button(action: showSetup) {
                Panel { HStack(spacing: 12) {
                    Image(systemName: "square.3.layers.3d").font(.title2)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Valgte pakker").font(.caption)
                        Text(room.settings.packs.compactMap { id in Pack.all.first { $0.id == id }?.title }.joined(separator: " · "))
                            .font(.caption.weight(.semibold)).padding(.horizontal, 9).padding(.vertical, 4).background(Color.violet, in: RoundedRectangle(cornerRadius: 6))
                    }; Spacer(); Image(systemName: "chevron.right")
                } }
            }.buttonStyle(.plain).disabled(!room.isHost)
            if room.ownSeat?.away == true {
                Button("Jeg er tilbage") { send(.init(type: "return")) }.buttonStyle(LoungeButtonStyle())
            } else if room.isHost {
                Button("Start spil") { send(.init(type: "start")) }.buttonStyle(LoungeButtonStyle()).disabled(client.busy || room.players.filter { !$0.away && !$0.late }.count < 3 || room.players.contains { !$0.away && !$0.late && $0.id != room.hostID && !$0.ready })
                Text("I skal være mindst 3. Alle gæster skal være klar.").font(.footnote).foregroundStyle(Color.lilac)
            } else {
                Button(room.ownSeat?.ready == true ? "Jeg er ikke klar endnu" : "Jeg er klar") { send(.init(type: "ready", value: .bool(!(room.ownSeat?.ready ?? false)))) }.buttonStyle(LoungeButtonStyle())
                Text("\(room.players.first { $0.id == room.hostID }?.name ?? "Værten") starter spillet, når alle er klar.").font(.footnote).foregroundStyle(Color.lilac)
            }
        }
    }
    private var questionScene: SceneArtwork {
        guard let round = room.round else { return .lounge }
        if round.backLocked || (room.phase == "private" && round.privateLocked) { return .waiting }
        if room.phase == "private" { return .privateRound }
        if round.answerLocked { return .backing }
        return round.kind == "personal" ? .guess : .question
    }
    private var question: some View {
        Screen(scene: questionScene, spacing: 12) {
            if let round = room.round {
                roundHeader(round)
                if round.kind == "personal" { Text(Pack.all.first { $0.id == round.pack }?.title ?? "Gratis mix").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 6).background(Color.violet.opacity(0.75), in: Capsule()) }
                if !round.backLocked && !(room.phase == "private" && round.privateLocked) {
                    Text(round.prompt).font(.editorial(round.answerLocked || (round.kind == "personal" && room.phase != "private") ? 21 : 27)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
                if room.fallbackNotice { Text("For få private svar. Her er et fælles spørgsmål i stedet.").font(.footnote).foregroundStyle(Color.lilac) }
                if room.phase == "private" {
                    if round.privateLocked { waiting(privateStep: true) }
                    else {
                        Text("Kun det samlede antal ja-svar bliver vist. I små grupper kan man stadig gætte, hvem der svarede hvad.").font(.footnote).multilineTextAlignment(.center).foregroundStyle(Color.lilac)
                        Color.clear.frame(height: 165)
                        HStack(spacing: 12) {
                            PersonalChoice(title: "Ja", selected: privateAnswer == "yes") { privateAnswer = "yes" }
                            PersonalChoice(title: "Nej", selected: privateAnswer == "no") { privateAnswer = "no" }
                        }
                        Button("Lås dit svar") { if let privateAnswer { send(.init(type: "private", value: .text(privateAnswer))) } }.buttonStyle(LoungeButtonStyle()).disabled(privateAnswer == nil || client.busy)
                        Button("Spring over") { send(.init(type: "private", value: .text("skip"))) }.padding(10).disabled(client.busy)
                    }
                } else if !round.answerLocked {
                    if round.kind == "personal" {
                        Text("Hvor mange svarede ja?").font(.editorial(28)).multilineTextAlignment(.center)
                        Text("\(round.responseCount ?? 0) svar i alt · Dit eget svar tæller med").font(.footnote).multilineTextAlignment(.center)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(0...(round.responseCount ?? 0), id: \.self) { number in
                                NumberChoice(number: number, selected: answer == number) { answer = number }
                            }
                        }
                    } else {
                        ForEach(Array(round.options.enumerated()), id: \.offset) { index, title in Choice(title: title, selected: answer == index) { answer = index } }
                    }
                    Spacer(minLength: round.kind == "personal" ? 135 : 135)
                    Button(round.kind == "personal" ? "Lås dit gæt" : "Lås dit svar") { if let answer { send(.init(type: "answer", value: .number(answer))) } }.buttonStyle(LoungeButtonStyle()).disabled(answer == nil || client.busy)
                } else if !round.backLocked {
                    Text("Hvem satser du på?").font(.editorial()).multilineTextAlignment(.center)
                    Text("Du får 1 point, hvis din ven svarer rigtigt.").font(.footnote).multilineTextAlignment(.center)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 98))], spacing: 9) {
                        ForEach(room.players.filter { $0.id != room.me && !$0.away && !$0.late }) { seat in
                            Button { backedID = seat.id } label: { SeatCard(seat: seat, host: false, selected: backedID == seat.id) }.buttonStyle(.plain).accessibilityAddTraits(backedID == seat.id ? .isSelected : [])
                        }
                    }
                    Button(backedID.flatMap { id in room.players.first { $0.id == id }.map { "Sats på \($0.name)" } } ?? "Vælg en ven") { if let backedID { send(.init(type: "back", playerID: backedID)) } }.buttonStyle(LoungeButtonStyle()).disabled(backedID == nil || client.busy)
                } else { waiting(privateStep: false) }
                Button("Rapportér spørgsmål") { report = true }.font(.caption).foregroundStyle(Color.lilac).padding(8)
            }
        }
    }
    private func roundHeader(_ round: RoundSnapshot) -> some View {
        HStack {
            Text("Runde \(round.number)").font(.subheadline)
            Spacer()
            if let deadline = round.deadline, !round.backLocked && !(room.phase == "private" && round.privateLocked) {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    let seconds = max(0, Int(ceil((deadline - client.serverNow) / 1000)))
                    Text("\(seconds)").font(.title2.bold().monospacedDigit()).frame(width: 58, height: 58)
                        .background(Circle().stroke(Color.violet.opacity(0.6), lineWidth: 6))
                        .overlay(Circle().trim(from: 0, to: min(1, max(0, Double(seconds) / Double(round.answerLocked ? room.settings.backingSeconds : room.settings.answerSeconds)))).stroke(Color.lime, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))).accessibilityLabel("\(seconds) sekunder tilbage")
                }
            }
            Spacer(); Text("\(room.ownSeat?.score ?? 0) / \(room.settings.finish)").font(.subheadline.monospacedDigit())
        }
    }
    private func waiting(privateStep: Bool) -> some View {
        VStack(spacing: 20) {
            Text("Dit svar er låst").font(.editorial()).multilineTextAlignment(.center)
            Text("Vi venter på de sidste …")
            Spacer(minLength: 282)
            if privateStep {
                Panel { VStack(spacing: 10) {
                    Text("Når alle har valgt, gætter I på antallet af ja-svar.").font(.footnote).multilineTextAlignment(.center)
                    HStack { Spacer(); ForEach(0..<room.players.filter { !$0.away && !$0.late }.count, id: \.self) { _ in Circle().fill(Color.lilac.opacity(0.4)).frame(width: 22, height: 22) }; Spacer() }
                } }
            } else {
                Panel { VStack(spacing: 12) {
                    Text("\(room.players.filter(\.complete).count) har valgt færdigt").font(.headline)
                    ForEach(room.players.filter { !$0.late }) { seat in
                        HStack { Text(seat.name); Spacer(); Label(seat.complete ? "Færdig" : "Venter", systemImage: seat.complete ? "checkmark.circle.fill" : "ellipsis.circle").foregroundStyle(seat.complete ? Color.lime : Color.lilac) }
                    }
                } }
            }
            if room.isHost {
                Menu("En spiller sidder over?") { ForEach(room.players.filter { !$0.away && !$0.late && $0.id != room.me }) { seat in Button(seat.name) { send(.init(type: "away", playerID: seat.id)) } } }
            }
        }
    }
    private var reveal: some View {
        Screen(scene: .backing, spacing: 9) {
            if let round = room.round {
                Text(round.kind == "personal" ? "Så mange svarede ja" : "Det rigtige svar").font(.editorial()).multilineTextAlignment(.center)
                Text(round.kind == "personal" ? "\(round.correct ?? 0) af \(round.responseCount ?? 0)" : round.correct.flatMap { round.options.indices.contains($0) ? round.options[$0] : nil } ?? "")
                    .font(.editorial(48)).foregroundStyle(Color.lime).multilineTextAlignment(.center)
                if round.kind == "personal", let count = round.responseCount, let yes = round.correct {
                    HStack(spacing: 10) { ForEach(0..<count, id: \.self) { index in Circle().fill(index < yes ? Color.lime : Color.violet).frame(width: 29, height: 29) } }.accessibilityHidden(true)
                    Text("\(round.results.filter { $0.own > 0 }.count) gættede rigtigt").font(.subheadline).padding(.vertical, 10)
                }
                if round.revealStage >= 1 {
                    ForEach(round.results) { result in resultRow(result, round: round, showPoints: round.revealStage >= 2) }
                } else { CharacterView(index: 1, size: 190) }
                if round.revealStage >= 3 { Text("Videre til brættet …").font(.headline); WindingBoard(room: room).frame(height: 370) }
            }
        }
    }
    private var board: some View {
        Screen(scene: room.phase == "finale" ? .finale : .board, spacing: 9) {
            if room.phase == "finale" {
                Text(room.winners.count > 1 ? "I deler sejren!" : "\(room.players.first { room.winners.contains($0.id) }?.name ?? "I") vinder!").font(.editorial(38)).multilineTextAlignment(.center)
                Text("Den var åbenbart god nok.")
                HStack { ForEach(room.players.filter { room.winners.contains($0.id) }) { CharacterView(index: $0.character, size: 150) } }.accessibilityHidden(true)
                standings
                if room.isHost { Button("En til?") { send(.init(type: "rematch")) }.buttonStyle(LoungeButtonStyle()) }
                else { Text("Værten kan starte en ny kamp.").foregroundStyle(Color.lilac) }
            } else {
                Text(room.players.filter { !$0.away && !$0.late }.count < 3 ? "Vi mangler en spiller" : "Sådan står I").font(.editorial()).multilineTextAlignment(.center)
                if room.players.filter({ !$0.away && !$0.late }).count < 3 { Text("Spillet fortsætter, når mindst 3 er aktive.").multilineTextAlignment(.center) }
                WindingBoard(room: room).frame(height: 350).padding(.horizontal, -18)
                if let own = room.round?.results.first(where: { $0.playerID == room.me }) {
                    Panel {
                        HStack(alignment: .top) {
                            Text("+\(own.points) point").font(.editorial(27)).foregroundStyle(Color.lime)
                            Spacer(); VStack(alignment: .leading, spacing: 6) { Text("Dit svar       +\(own.own)"); Text("Din satsning +\(own.backing)") }.font(.caption)
                        }
                    }
                }
                Button("Se alle svar") { allResults = true }.font(.subheadline).padding(8)
                HStack(spacing: 10) {
                    reaction("applause", "👏", "Klapsalve"); reaction("laughter", "😂", "Grin"); reaction("surprise", "😮", "Overraskelse"); reaction("side-eye", "😏", "Sideblik")
                }
                if !room.reactions.isEmpty {
                    Text(room.reactions.map { reaction in
                        let name = room.players.first { $0.id == reaction.playerID }?.name ?? "En ven"
                        let label = ["applause": "klapper", "laughter": "griner", "surprise": "er overrasket", "side-eye": "sender et sideblik"][reaction.value] ?? "reagerer"
                        return "\(name) \(label)"
                    }.joined(separator: " · ")).font(.caption).foregroundStyle(Color.lilac)
                }
                if room.phase == "countdown" {
                    TimelineView(.periodic(from: .now, by: 0.2)) { _ in Text("Næste runde om \(max(0, Int(ceil(((room.countdownAt ?? client.serverNow) - client.serverNow)/1000))))").font(.headline).frame(maxWidth: .infinity).padding(18).background(Color.violet, in: RoundedRectangle(cornerRadius: 17)) }
                } else if room.ownSeat?.away == true {
                    Button("Jeg er tilbage") { send(.init(type: "return")) }.buttonStyle(LoungeButtonStyle())
                } else {
                    Button(room.ownSeat?.ready == true ? "Vent, jeg er ikke klar" : "Klar til næste runde") { send(.init(type: "ready", value: .bool(!(room.ownSeat?.ready ?? false)))) }.buttonStyle(LoungeButtonStyle()).disabled(client.busy)
                }
                if room.settings.drinking {
                    Text("Drikkeregler er valgfrie. Du kan altid springe over.").font(.footnote).foregroundStyle(Color.lilac).multilineTextAlignment(.center)
                }
            }
        }
    }
    private var standings: some View {
        VStack(spacing: 6) {
            ForEach(Array(room.players.sorted { $0.score > $1.score }.enumerated()), id: \.element.id) { rank, seat in
                HStack(spacing: 12) { Text("\(rank + 1)").font(.headline).frame(width: 18); CharacterView(index: seat.character, size: 36); Text(seat.name).font(.subheadline.weight(.semibold)); Spacer(); Text("\(seat.score)").font(.headline) }
                    .foregroundStyle(room.winners.contains(seat.id) ? Color.lime : Color.cream)
                    .padding(.horizontal, 13).padding(.vertical, 5).background(Color.lounge.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(room.winners.contains(seat.id) ? Color.lime : Color.lilac.opacity(0.25), lineWidth: room.winners.contains(seat.id) ? 2 : 1))
            }
        }
    }
    private var paused: some View {
        Screen(scene: .waiting) {
            Text("Vi mangler en spiller").font(.editorial(30)).multilineTextAlignment(.center)
            Text("Spillet fortsætter, når mindst 3 er aktive.").font(.subheadline).multilineTextAlignment(.center)
            Spacer(minLength: 245)
            HStack(spacing: 7) { ForEach(room.players) { seat in SeatCard(seat: seat, host: seat.id == room.hostID, compact: true).opacity(seat.away ? 0.45 : 1) } }
            Panel { HStack { VStack(alignment: .leading) { Text("\(room.players.filter { !$0.away && !$0.late }.count) aktive spillere").font(.headline); Text("Stillingen er gemt.").font(.caption) }; Spacer(); Text(room.code).font(.headline.monospaced()) } }
            if room.isHost { Button("Tilbage til lobbyen") { send(.init(type: "end")) }.buttonStyle(LoungeButtonStyle(primary: false)); Text("Det afslutter den igangværende kamp.").font(.caption) }
            if room.ownSeat?.away == true { Button("Jeg er tilbage") { send(.init(type: "return")) }.buttonStyle(LoungeButtonStyle()) }
        }
    }
    private var sittingOut: some View {
        Screen(scene: .waiting) { Text("Du sidder over").font(.editorial()); Spacer(minLength: 340); Text("Din plads og dine point er gemt."); Button("Jeg er tilbage") { send(.init(type: "return")) }.buttonStyle(LoungeButtonStyle()); Text("Du er med igen ved næste runde.").font(.footnote) }
    }
    private var waitingForMatch: some View {
        Screen(scene: .waiting) { Text("Du er med næste gang").font(.editorial()); Spacer(minLength: 340); Text("De andre er midt i en kamp. Din plads er klar til den næste.").multilineTextAlignment(.center); standings }
    }
    private func resultRow(_ result: RoundResult, round: RoundSnapshot, showPoints: Bool) -> some View {
        let seat = room.players.first { $0.id == result.playerID }
        return Panel {
            HStack {
                CharacterView(index: seat?.character ?? 0, size: 50).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(seat?.name ?? "Spiller").font(.headline)
                    Text(result.answer.map { round.kind == "personal" ? "Gæt: \($0)" : round.options.indices.contains($0) ? round.options[$0] : "—" } ?? "Intet svar").font(.caption)
                    Text("Satsede på \(room.players.first { $0.id == result.back }?.name ?? "ingen")").font(.caption)
                }
                Spacer(); if showPoints { Text("+\(result.points)").font(.title.bold()).foregroundStyle(Color.lime) }
            }
        }
    }
    private func reaction(_ value: String, _ emoji: String, _ label: String) -> some View {
        Button { send(.init(type: "reaction", value: .text(value))) } label: { Text(emoji).font(.title).frame(maxWidth: .infinity, minHeight: 52).background(Color.lounge, in: RoundedRectangle(cornerRadius: 14)) }.buttonStyle(.plain).accessibilityLabel(label)
    }
    private func send(_ action: CommandAction) { Task { await client.command(action); if client.problem == nil && ["answer", "back", "private"].contains(action.type) { Feedback.shared.play("lock") } } }
}
