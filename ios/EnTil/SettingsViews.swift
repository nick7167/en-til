import SwiftUI
import StoreKit

struct SetupView: View {
    @Bindable var client: GameClient
    @Bindable var store: PackStore
    let original: GameSettings
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GameSettings
    @State private var discard = false
    @State private var adultPrompt = false
    init(client: GameClient, store: PackStore, original: GameSettings) {
        self.client = client; self.store = store; self.original = original
        _draft = State(initialValue: original)
    }
    var body: some View {
        Screen {
            Text("Spilindstillinger").font(.editorial())
            Panel {
                VStack(alignment: .leading, spacing: 17) {
                    Text("Mållinje").font(.headline)
                    Text("Spil til det antal point, der passer jer.").font(.footnote).foregroundStyle(Color.lilac)
                    HStack { ForEach([10, 20, 30], id: \.self) { number in Button("\(number)") { draft.finish = number }.buttonStyle(LoungeButtonStyle(primary: draft.finish == number)) } }
                    Stepper("\(draft.finish) felter", value: $draft.finish, in: 5...50)
                }
            }
            Panel {
                VStack(spacing: 18) {
                    Toggle("Spil med tid", isOn: $draft.timed)
                    if draft.timed {
                        Stepper("Svar: \(draft.answerSeconds) sek.", value: $draft.answerSeconds, in: 10...60, step: 5)
                        Stepper("Satsning: \(draft.backingSeconds) sek.", value: $draft.backingSeconds, in: 5...30, step: 5)
                        Text("I personlige runder bruges svartiden også til det private svar.").font(.footnote).foregroundStyle(Color.lilac)
                    }
                }
            }
            Panel { VStack(alignment: .leading, spacing: 8) {
                Toggle("Drikkeregler", isOn: Binding(get: { draft.drinking }, set: { value in
                    if value && !UserDefaults.standard.bool(forKey: "adult") { adultPrompt = true }
                    else { draft.drinking = value }
                }))
                Text("Valgfrit for den enkelte. Ingen behøver drikke for at være med.").font(.footnote).foregroundStyle(Color.lilac)
            } }
            Text("Vælg pakker").font(.editorial(27)).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Pack.all) { pack in
                if pack.id == "free" || client.owned.contains(pack.id) {
                    Button {
                        if pack.adult && !UserDefaults.standard.bool(forKey: "adult") { adultPrompt = true; return }
                        if draft.packs.contains(pack.id) { draft.packs.removeAll { $0 == pack.id } } else { draft.packs.append(pack.id) }
                    } label: { PackRow(pack: pack, trailing: draft.packs.contains(pack.id) ? "Valgt ✓" : "Vælg") }.buttonStyle(.plain)
                } else {
                    NavigationLink { PackDetailView(pack: pack, client: client, store: store) } label: { PackRow(pack: pack, trailing: store.product(pack.id)?.displayPrice ?? "Se pakke") }.buttonStyle(.plain)
                }
            }
            Button("Gem ændringer") {
                Task {
                    await client.command(.init(type: "settings", settings: draft))
                    if client.problem == nil && !client.needsAdult {
                        UserDefaults.standard.set(draft.drinking, forKey: "hostDrinking"); dismiss()
                    }
                }
            }.buttonStyle(LoungeButtonStyle()).disabled(draft.packs.isEmpty || client.busy)
            Text("Når du gemmer, skal gæsterne melde sig klar igen.").font(.footnote).foregroundStyle(Color.lilac)
        }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Luk") { if draft != original { discard = true } else { dismiss() } } } }
        .interactiveDismissDisabled(draft != original)
        .confirmationDialog("Kassér dine ændringer?", isPresented: $discard, titleVisibility: .visible) {
            Button("Kassér ændringer", role: .destructive) { dismiss() }; Button("Rediger videre", role: .cancel) {}
        }
        .alert("Er du fyldt 18 år?", isPresented: $adultPrompt) {
            Button("Ja, jeg er fyldt 18 år") { Task { await client.confirmAdult() } }
            Button("Nej, gå tilbage", role: .cancel) {}
        } message: { Text("Voksenpakker og drikkeregler kræver, at du er fyldt 18 år.") }
        .onChange(of: store.purchasedPack) { _, id in
            if id == "launch-bundle" { draft.packs = Pack.all.map(\.id) }
            else if let id, client.owned.contains(id), !draft.packs.contains(id) { draft.packs.append(id) }
        }
    }
}
struct PackRow: View {
    let pack: Pack
    let trailing: String
    var body: some View {
        Panel {
            HStack(spacing: 13) {
                Group {
                    if pack.id == "free" { CharacterView(index: 0, size: 60).background(Color.violet) }
                    else { Image("Pack-\(pack.id)").resizable().scaledToFill() }
                }.frame(width: 60, height: 67).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.title).font(.headline)
                    if let intensity = pack.intensity { Text(intensity).font(.caption.bold()).foregroundStyle(Color.lilac) }
                    Text(pack.subtitle).font(.caption).foregroundStyle(Color.cream.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0); Text(trailing).font(.subheadline.bold()).multilineTextAlignment(.trailing)
            }
        }
    }
}
struct ShopView: View {
    @Bindable var client: GameClient
    @Bindable var store: PackStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Screen {
            Text("Mere på spil").font(.editorial())
            ForEach(Pack.all.filter { $0.id != "free" }) { pack in
                NavigationLink { PackDetailView(pack: pack, client: client, store: store) } label: { PackRow(pack: pack, trailing: client.owned.contains(pack.id) ? "Købt ✓" : store.product(pack.id)?.displayPrice ?? "Se pakke") }.buttonStyle(.plain)
            }
            NavigationLink { BundleView(client: client, store: store) } label: {
                Panel { HStack { CharacterView(index: 0, size: 58); VStack(alignment: .leading) { Text("Alle seks pakker").font(.headline); Text("Mere at grine af. Mindre at tænke på.").font(.caption) }; Spacer(); Text(store.product("launch-bundle")?.displayPrice ?? "Se mere").font(.headline) } }
            }.buttonStyle(.plain)
            if let route = store.cheapestRoute(owned: client.owned) { Text(route).font(.footnote).foregroundStyle(Color.lilac) }
            Button("Gendan køb") { Task { await store.restore() } }.padding(10)
            if let message = store.message { Text(message).font(.footnote).multilineTextAlignment(.center) }
        }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Luk") { dismiss() } } }
            .task { await store.load(); try? await client.refreshOwnership() }
    }
}
struct PackDetailView: View {
    let pack: Pack
    @Bindable var client: GameClient
    @Bindable var store: PackStore
    @State private var adultPrompt = false
    var body: some View {
        Screen {
            Text(client.owned.contains(pack.id) ? "Pakken er din" : pack.title).font(.editorial(43)).multilineTextAlignment(.center)
            if let intensity = pack.intensity { Text(intensity).font(.subheadline.bold()).foregroundStyle(Color.ink).padding(.horizontal, 20).padding(.vertical, 6).background(Color.lilac, in: Capsule()) }
            Text(pack.subtitle).multilineTextAlignment(.center)
            Image("Pack-\(pack.id)").resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 27)).accessibilityHidden(true)
            if client.owned.contains(pack.id) { Text(pack.title).font(.editorial(30)) }
            Text("Du køber pakken én gang.\nAlle i dit spil kan være med.").multilineTextAlignment(.center)
            if client.owned.contains(pack.id) { Label("Købt", systemImage: "checkmark.circle.fill").font(.title2.bold()).foregroundStyle(Color.lime) }
            else if let product = store.product(pack.id) {
                Button("Køb for \(product.displayPrice)") {
                    if pack.adult && !UserDefaults.standard.bool(forKey: "adult") { adultPrompt = true }
                    else { Task { await store.buy(pack.id) } }
                }.buttonStyle(LoungeButtonStyle()).disabled(store.purchasing)
            } else { Text("Prisen er ikke tilgængelig lige nu.").font(.footnote); Button("Hent pris igen") { Task { await store.load() } } }
            Text("Engangskøb").font(.caption).foregroundStyle(Color.lilac)
            Button("Gendan køb") { Task { await store.restore() } }.padding(8)
            if let message = store.message { Text(message).font(.footnote).multilineTextAlignment(.center) }
        }.alert("Er du fyldt 18 år?", isPresented: $adultPrompt) {
            Button("Ja, jeg er fyldt 18 år") { UserDefaults.standard.set(true, forKey: "adult"); Task { await store.buy(pack.id) } }
            Button("Nej, gå tilbage", role: .cancel) {}
        } message: { Text("Denne pakke indeholder voksenindhold.") }
    }
}
struct BundleView: View {
    @Bindable var client: GameClient
    @Bindable var store: PackStore
    @State private var adultPrompt = false
    var body: some View {
        Screen {
            Text("Alle seks pakker").font(.editorial(40)).multilineTextAlignment(.center)
            Text("Hele holdet. Hele pakken.")
            HStack(spacing: 0) { ForEach(0..<4, id: \.self) { CharacterView(index: $0, size: 77) } }.accessibilityHidden(true)
            ForEach(Pack.all.filter { $0.id != "free" }) { pack in HStack { Text(pack.title); Spacer(); Text(client.owned.contains(pack.id) ? "Købt ✓" : store.product(pack.id)?.displayPrice ?? "—").foregroundStyle(Color.lilac) }.padding(.vertical, 7) }
            Text("Indeholder også frække og meget frække spørgsmål. De seks viste pakker følger med; fremtidige pakker sælges separat.").font(.footnote)
            if let route = store.cheapestRoute(owned: client.owned) { Panel { Text(route).font(.subheadline) } }
            Text("Tidligere køb modregnes ikke.").font(.footnote).foregroundStyle(Color.lilac)
            if let product = store.product("launch-bundle") {
                Button("Køb alle seks for \(product.displayPrice)") {
                    if !UserDefaults.standard.bool(forKey: "adult") { adultPrompt = true }
                    else { Task { await store.buy("launch-bundle") } }
                }.buttonStyle(LoungeButtonStyle()).disabled(store.purchasing || Pack.all.filter { $0.id != "free" }.allSatisfy { client.owned.contains($0.id) })
            }
            Button("Gendan køb") { Task { await store.restore() } }
            if let message = store.message { Text(message).font(.footnote) }
        }.alert("Er du fyldt 18 år?", isPresented: $adultPrompt) {
            Button("Ja, jeg er fyldt 18 år") { UserDefaults.standard.set(true, forKey: "adult"); Task { await store.buy("launch-bundle") } }
            Button("Nej, gå tilbage", role: .cancel) {}
        } message: { Text("Samlepakken indeholder voksenindhold.") }
    }
}
struct PreferencesView: View {
    @Bindable var client: GameClient
    @Bindable var store: PackStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("sound") private var sound = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("drinking") private var drinking = false
    @State private var adultPrompt = false
    var body: some View {
        Screen {
            Text("Indstillinger").font(.editorial())
            if client.room == nil || client.room?.phase == "lobby" { NavigationLink("Rediger profil") { ProfileView(client: client) } }
            Panel { VStack(spacing: 20) { Toggle("Lydeffekter", isOn: $sound); Divider(); Toggle("Vibration", isOn: $haptics) } }
            Text("Animationer følger indstillingerne på din iPhone.").font(.footnote).foregroundStyle(Color.lilac)
            Panel { VStack(alignment: .leading, spacing: 8) {
                Toggle("Vis drikkeregler for mig", isOn: Binding(get: { drinking }, set: { value in
                    if value && !UserDefaults.standard.bool(forKey: "adult") { adultPrompt = true; return }
                    Task {
                        if client.room != nil { await client.command(.init(type: "drinking", value: .bool(value))) }
                        if client.problem == nil { drinking = value }
                    }
                }))
                Text("Du kan altid springe over. Det påvirker aldrig dine point.").font(.footnote).foregroundStyle(Color.lilac)
            } }
            NavigationLink("Sådan spiller I") { RulesView() }
            Button("Gendan køb") { Task { await store.restore() } }.padding(8)
            NavigationLink("Privatliv") { PrivacyView() }
            Text("Version 0.1 · Under udvikling").font(.caption).foregroundStyle(Color.lilac)
            if let message = store.message { Text(message).font(.footnote) }
        }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Luk") { dismiss() } } }
            .alert("Er du fyldt 18 år?", isPresented: $adultPrompt) {
                Button("Ja, jeg er fyldt 18 år") { Task { await client.confirmAdult() } }
                Button("Nej, gå tilbage", role: .cancel) {}
            }
    }
}
struct RulesView: View {
    var body: some View {
        Screen {
            Text("Samme fjollede hold").font(.editorial()).multilineTextAlignment(.center)
            CharacterView(index: 2, size: 130).accessibilityHidden(true)
            rule("1", "Svar selv", "Alle ser det samme spørgsmål. Vælg et svar, og lås det. Når spillet har bekræftet dit valg, kan det ikke ændres.")
            rule("2", "Sats på en ven", "Vælg en anden spiller, du tror svarer rigtigt. I må gerne satse på den samme.")
            rule("3", "Ryk frem", "Du får 1 point for dit eget rigtige svar og 1 point, hvis din ven svarer rigtigt. Din vens satsning ændrer ikke dine point.")
            rule("?", "Personlige runder", "Svar privat ja eller nej, eller spring over. Så gætter alle på antallet af ja-svar. De nærmeste gæt tæller som rigtige, også ved lighed. Dit eget svar tæller med.")
            Text("Kun det samlede antal private svar vises. I små grupper kan I stadig drage slutninger om hinanden. Hvis færre end 3 svarer, får I et andet spørgsmål.").font(.footnote).foregroundStyle(Color.lilac)
            rule("★", "Først i mål", "Hele runden tælles færdig. Den, der er længst fremme, vinder. Står flere lige længst fremme, deler de sejren.")
            Text("Tiden løber videre, hvis forbindelsen ryger. Et ubekræftet valg tæller ikke. Du kan stadig satse, selv om du ikke nåede dit svar. Drikkeregler er altid valgfrie.").font(.footnote)
        }
    }
    private func rule(_ number: String, _ title: String, _ text: String) -> some View { Panel { HStack(alignment: .top, spacing: 15) { Text(number).font(.editorial(30)).foregroundStyle(Color.lime); VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(text).font(.subheadline) } } } }
}
struct PrivacyView: View {
    var body: some View {
        Screen {
            Text("Privatliv").font(.editorial())
            Text("Dit navn og din figur vises til spillerne i dit rum. Din iPhone gemmer din profil og en sikker nøgle, så du kan komme tilbage til din plads.")
            Text("Personlige ja- og nej-svar deles ikke enkeltvis. De bruges til at beregne et samlet antal og slettes fra den aktive spiltilstand, før I gætter. Små grupper kan stadig drage slutninger om hinanden.")
            Text("Vi gemmer køb, spørgsmålsrapporter og ID'er på spørgsmål, værten har set. Vi viser ikke en historik over dine spil eller personlige svar.")
            Text("Den endelige privatlivspolitik med kontaktoplysninger og opbevaringstider skal færdiggøres før udgivelse.").font(.footnote).foregroundStyle(Color.lilac)
        }
    }
}
struct ResultsView: View {
    let room: RoomSnapshot
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Screen {
            Text("Rundens resultat").font(.editorial())
            if let round = room.round {
                Text("Runde \(round.number)")
                Text(round.kind == "personal" ? "\(round.correct ?? 0) af \(round.responseCount ?? 0) svarede ja" : "Det rigtige svar: \(round.correct.flatMap { round.options.indices.contains($0) ? round.options[$0] : nil } ?? "—")").font(.headline).foregroundStyle(Color.lime)
                ForEach(round.results) { result in
                    Panel { VStack(alignment: .leading, spacing: 8) {
                        HStack { CharacterView(index: room.players.first { $0.id == result.playerID }?.character ?? 0, size: 40); Text(room.players.first { $0.id == result.playerID }?.name ?? "Spiller").font(.headline); Spacer(); Text("+\(result.points)").font(.title2.bold()).foregroundStyle(Color.lime) }
                        Text("Svar: \(result.answer.map { round.kind == "personal" ? String($0) : round.options.indices.contains($0) ? round.options[$0] : "—" } ?? "—")")
                        Text("Satsede på: \(room.players.first { $0.id == result.back }?.name ?? "—")")
                        if room.settings.drinking { Text("Valgfrie slurke: \(result.sips.map(String.init) ?? "—")") }
                    }.font(.subheadline) }
                }
                if let fact = round.fact { DisclosureGroup("Fakta og kilde") { VStack(alignment: .leading, spacing: 10) { Text(fact); if let source = round.source, let url = URL(string: source), url.scheme == "https" { Link("Se kilde", destination: url) } }.padding(.vertical, 10) } }
                if room.settings.drinking { Text("Drikkeregler er valgfrie. Du kan altid springe over.").font(.footnote) }
            }
            Button("Luk") { dismiss() }.buttonStyle(LoungeButtonStyle())
        }
    }
}
struct ReportView: View {
    @Bindable var client: GameClient
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "wrong"
    @State private var note = ""
    var body: some View {
        Screen {
            Text("Noget galt med spørgsmålet?").font(.editorial()).multilineTextAlignment(.center)
            Picker("Årsag", selection: $reason) { Text("Forkert svar").tag("wrong"); Text("Uklart spørgsmål").tag("unclear"); Text("Upassende indhold").tag("inappropriate"); Text("Noget andet").tag("other") }.pickerStyle(.inline)
            TextField("Tilføj en besked (valgfrit)", text: $note, axis: .vertical).lineLimit(3...6).padding(16).background(Color.lounge, in: RoundedRectangle(cornerRadius: 15))
            Text("Rapporten ændrer ikke pointene i denne runde.").font(.footnote).foregroundStyle(Color.lilac)
            Button("Send rapport") { Task { await client.report(reason: reason, note: note); if client.problem == nil { dismiss() } } }.buttonStyle(LoungeButtonStyle()).disabled(client.busy || note.count > 500)
        }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Luk") { dismiss() } } }
    }
}
