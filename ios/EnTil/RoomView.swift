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
            Panel {
                VStack(spacing: 5) {
                    Text("Spilkode").font(.caption)
                    Button { UIPasteboard.general.string = room.code } label: { HStack { Text(room.code).font(.system(size: 44, weight: .black, design: .monospaced)).tracking(7); Image(systemName: "doc.on.doc").font(.caption) } }
                        .buttonStyle(.plain).accessibilityLabel("Kopiér spilkode \(room.code)")
                }
            }
            Text("\(room.players.count) spillere").font(.caption)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 125))], spacing: 12) {
                ForEach(room.players) { seat in
                    SeatCard(seat: seat, host: seat.id == room.hostID)
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
                            Text(room.settings.packs.compactMap { id in Pack.all.first { $0.id == id }?.title }.joined(separator: " · ")).font(.caption).foregroundStyle(Color.lilac)
                        }
                        Spacer(); Image(systemName: "chevron.right")
                    }
                }
            }.buttonStyle(.plain).disabled(!room.isHost)
            if room.ownSeat?.away == true {
                Button("Jeg er tilbage") { send(.init(type: "return")) }.buttonStyle(LoungeButtonStyle())
            } else if room.isHost {
                Button("Start spil") { send(.init(type: "start")) }.buttonStyle(LoungeButtonStyle()).disabled(client.busy || room.players.filter { !$0.away && !$0.late }.count < 3 || room.players.contains { !$0.away && !$0.late && $0.id != room.hostID && !$0.ready })
                Text("I skal være mindst 3. Alle gæster skal være klar.").font(.footnote).foregroundStyle(Color.lilac)
            } else {
                Button(room.ownSeat?.ready == true ? "Jeg er ikke klar endnu" : "Jeg er klar") { send(.init(type: "ready", value: .bool(!(room.ownSeat?.ready ?? false)))) }.buttonStyle(LoungeButtonStyle())
                Text("Værten starter, når alle er klar.").font(.footnote).foregroundStyle(Color.lilac)
            }
        }
    }
    private var question: some View {
        Screen {
            if let round = room.round {
                roundHeader(round)
                Text(Pack.all.first { $0.id == round.pack }?.title ?? "Gratis mix").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 8).background(Color.violet, in: Capsule())
                Text(round.prompt).font(.editorial(round.answerLocked ? 25 : 30)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                if room.fallbackNotice { Text("For få private svar. Her er et fælles spørgsmål i stedet.").font(.footnote).foregroundStyle(Color.lilac) }
                if room.phase == "private" {
                    if round.privateLocked { waiting(privateStep: true) }
                    else {
                        Text("Kun det samlede antal ja-svar bliver vist. I små grupper kan man stadig gætte, hvem der svarede hvad.").font(.footnote).multilineTextAlignment(.center).foregroundStyle(Color.lilac)
                        CharacterView(index: room.ownSeat?.character ?? 0, size: 155)
                        HStack(spacing: 12) {
                            Choice(title: "Ja", selected: privateAnswer == "yes") { privateAnswer = "yes" }
                            Choice(title: "Nej", selected: privateAnswer == "no") { privateAnswer = "no" }
                        }
                        Button("Lås dit svar") { if let privateAnswer { send(.init(type: "private", value: .text(privateAnswer))) } }.buttonStyle(LoungeButtonStyle()).disabled(privateAnswer == nil || client.busy)
                        Button("Spring over") { send(.init(type: "private", value: .text("skip"))) }.padding(10).disabled(client.busy)
                    }
                } else if !round.answerLocked {
                    if round.kind == "personal" {
                        Text("Hvor mange svarede ja?").font(.editorial(28)).multilineTextAlignment(.center)
                        Text("\(round.responseCount ?? 0) svar i alt · Dit eget svar tæller med").font(.footnote).multilineTextAlignment(.center)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82))], spacing: 12) {
                            ForEach(0...(round.responseCount ?? 0), id: \.self) { number in
                                Choice(title: String(number), selected: answer == number) { answer = number }
                            }
                        }
                    } else {
                        ForEach(Array(round.options.enumerated()), id: \.offset) { index, title in Choice(title: title, selected: answer == index) { answer = index } }
                    }
                    Button(round.kind == "personal" ? "Lås dit gæt" : "Lås dit svar") { if let answer { send(.init(type: "answer", value: .number(answer))) } }.buttonStyle(LoungeButtonStyle()).disabled(answer == nil || client.busy)
                    CharacterView(index: 2, size: 95).frame(maxWidth: .infinity, alignment: .trailing).accessibilityHidden(true)
                } else if !round.backLocked {
                    Text("Sats på en ven").font(.editorial()).multilineTextAlignment(.center)
                    Text("Du får 1 point, hvis din ven svarer rigtigt.").font(.footnote).multilineTextAlignment(.center)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
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
            if let deadline = round.deadline, !round.backLocked {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    let seconds = max(0, Int(ceil((deadline - client.serverNow) / 1000)))
                    Text("\(seconds)").font(.title2.bold().monospacedDigit()).frame(width: 58, height: 58)
                        .overlay(Circle().stroke(Color.lime, lineWidth: 5)).accessibilityLabel("\(seconds) sekunder tilbage")
                }
            }
            Spacer(); Text("\(room.ownSeat?.score ?? 0) / \(room.settings.finish)").font(.subheadline.monospacedDigit())
        }
    }
    private func waiting(privateStep: Bool) -> some View {
        VStack(spacing: 20) {
            Text("Dit valg er låst").font(.editorial()).multilineTextAlignment(.center)
            Text("Vi venter på de sidste …")
            LoungeIllustration()
            if privateStep {
                Text("Når alle har valgt, gætter I på antallet af ja-svar.").font(.footnote).multilineTextAlignment(.center)
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
        Screen {
            if let round = room.round {
                Text(round.kind == "personal" ? "Så mange svarede ja" : "Det rigtige svar").font(.editorial()).multilineTextAlignment(.center)
                Text(round.kind == "personal" ? "\(round.correct ?? 0) af \(round.responseCount ?? 0)" : round.correct.flatMap { round.options.indices.contains($0) ? round.options[$0] : nil } ?? "")
                    .font(.editorial(48)).foregroundStyle(Color.lime).multilineTextAlignment(.center)
                if round.revealStage >= 1 {
                    ForEach(round.results) { result in resultRow(result, round: round, showPoints: round.revealStage >= 2) }
                } else { CharacterView(index: 1, size: 190) }
                if round.revealStage >= 3 { Text("Videre til brættet …").font(.headline); WindingBoard(room: room).frame(height: 370) }
            }
        }
    }
    private var board: some View {
        Screen {
            if room.phase == "finale" {
                Text(room.winners.count > 1 ? "I deler sejren!" : "\(room.players.first { room.winners.contains($0.id) }?.name ?? "I") vinder!").font(.editorial(38)).multilineTextAlignment(.center)
                Text("Den var åbenbart god nok.")
                HStack { ForEach(room.players.filter { room.winners.contains($0.id) }) { CharacterView(index: $0.character, size: 110) } }.accessibilityHidden(true)
                standings
                if room.isHost { Button("En til?") { send(.init(type: "rematch")) }.buttonStyle(LoungeButtonStyle()) }
                else { Text("Værten kan starte en ny kamp.").foregroundStyle(Color.lilac) }
            } else {
                Text(room.players.filter { !$0.away && !$0.late }.count < 3 ? "Vi mangler en spiller" : "Sådan står I").font(.editorial()).multilineTextAlignment(.center)
                if room.players.filter({ !$0.away && !$0.late }).count < 3 { Text("Spillet fortsætter, når mindst 3 er aktive.").multilineTextAlignment(.center) }
                WindingBoard(room: room).frame(height: 430)
                if let own = room.round?.results.first(where: { $0.playerID == room.me }) {
                    Panel {
                        HStack(alignment: .top) {
                            Text("+\(own.points) point").font(.editorial(30)).foregroundStyle(Color.lime)
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
        VStack(spacing: 10) { ForEach(room.players.sorted { $0.score > $1.score }) { seat in Panel { HStack { CharacterView(index: seat.character, size: 43); Text(seat.name).font(.headline); Spacer(); Text("\(seat.score)").font(.title2.bold()).foregroundStyle(Color.lime) } } } }
    }
    private var sittingOut: some View {
        Screen { Text("Du sidder over").font(.editorial()); LoungeIllustration(); Text("Din plads og dine point er gemt."); Button("Jeg er tilbage") { send(.init(type: "return")) }.buttonStyle(LoungeButtonStyle()); Text("Du er med igen ved næste runde.").font(.footnote) }
    }
    private var waitingForMatch: some View {
        Screen { Text("Du er med næste gang").font(.editorial()); LoungeIllustration(); Text("De andre er midt i en kamp. Din plads er klar til den næste.").multilineTextAlignment(.center); standings }
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
