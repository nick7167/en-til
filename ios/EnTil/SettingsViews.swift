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
        Screen(scene: .plain, spacing: 12) {
            Text("Spilindstillinger").font(.editorial()).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                Text("Mållinje").font(.system(size: 18, weight: .semibold))
                Text("Spil til det antal point, der passer jer.").font(.footnote).foregroundStyle(Color.lilac)
                HStack(spacing: 12) {
                    ForEach([10, 20, 30], id: \.self) { number in
                        Button { draft.finish = number } label: {
                            Text("\(number)").font(.system(size: 18, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
                                .background(draft.finish == number ? Color.lime.opacity(0.12) : Color.lounge, in: RoundedRectangle(cornerRadius: 11))
                                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(draft.finish == number ? Color.lime : Color.lilac.opacity(0.3), lineWidth: draft.finish == number ? 2 : 1))
                        }.buttonStyle(.plain).accessibilityAddTraits(draft.finish == number ? .isSelected : [])
                    }
                }
                Divider()
                Text("Vælg selv").font(.system(size: 18, weight: .semibold))
                Text("Indstil præcis, hvor mange felter I vil spille.").font(.footnote).foregroundStyle(Color.lilac)
                SettingStepper(title: "Mållinje", value: $draft.finish, range: 5...50, unit: "felter")
                Divider()
                Toggle(isOn: $draft.timed) {
                    VStack(alignment: .leading, spacing: 3) { Text("Tid pr. runde").font(.system(size: 18, weight: .semibold)); Text("Spil med tid").font(.footnote).foregroundStyle(Color.lilac) }
                }
                if draft.timed {
                    SettingStepper(title: "Svar", value: $draft.answerSeconds, range: 10...60, step: 5, unit: "sek.", showTitle: true)
                    SettingStepper(title: "Satsning", value: $draft.backingSeconds, range: 5...30, step: 5, unit: "sek.", showTitle: true)
                    Label("I personlige runder bruges svartiden også til det private svar.", systemImage: "info.circle").font(.footnote).foregroundStyle(Color.lilac)
                }
                Divider()
                Toggle(isOn: Binding(get: { draft.drinking }, set: { value in
                    if value && !UserDefaults.standard.bool(forKey: "adult") { adultPrompt = true }
                    else { draft.drinking = value }
                })) {
                    VStack(alignment: .leading, spacing: 3) { Text("Drikkeregler").font(.system(size: 18, weight: .semibold)); Text("Valgfrit for den enkelte.").font(.footnote).foregroundStyle(Color.lilac) }
                }
                Divider()
                NavigationLink {
                    PackSelectionView(client: client, store: store, draft: $draft)
                } label: {
                    HStack { Text("Vælg pakker").font(.system(size: 18, weight: .semibold)); Spacer(); Text("\(draft.packs.count) valgt").foregroundStyle(Color.lilac); Image(systemName: "chevron.right") }.padding(.vertical, 8)
                }.buttonStyle(.plain)
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
private struct SettingStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    let unit: String
    var showTitle = false
    var body: some View {
        HStack(spacing: 12) {
            if showTitle { Text(title).font(.system(size: 17)).frame(maxWidth: .infinity, alignment: .leading) }
            HStack(spacing: 0) {
                Button { value = max(range.lowerBound, value - step) } label: { Image(systemName: "minus").font(.title3.weight(.semibold)).frame(width: 44, height: 44).background(Color.violet.opacity(0.6), in: RoundedRectangle(cornerRadius: 9)) }.disabled(value <= range.lowerBound).accessibilityLabel("Færre: \(title)")
                Text("\(value) \(unit)").font(.system(size: 17).monospacedDigit()).frame(maxWidth: .infinity).padding(.horizontal, 8)
                Button { value = min(range.upperBound, value + step) } label: { Image(systemName: "plus").font(.title3.weight(.semibold)).frame(width: 44, height: 44).background(Color.violet.opacity(0.6), in: RoundedRectangle(cornerRadius: 9)) }.disabled(value >= range.upperBound).accessibilityLabel("Flere: \(title)")
            }.background(Color.lounge, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.lilac.opacity(0.25)))
                .frame(maxWidth: showTitle ? 230 : .infinity)
        }.buttonStyle(.plain)
            .accessibilityElement(children: .ignore).accessibilityLabel(title).accessibilityValue("\(value) \(unit)")
            .accessibilityAdjustableAction { direction in
                switch direction { case .increment: value = min(range.upperBound, value + step); case .decrement: value = max(range.lowerBound, value - step); @unknown default: break }
            }
    }
}
private struct IntensityPill: View {
    let title: String
    var body: some View {
        Text(title).font(.caption.weight(.medium)).foregroundStyle(Color.ink)
            .padding(.horizontal, 12).padding(.vertical, 2)
            .background(title.contains("fræk") || title == "Fræk" ? Color(hex: 0xF19CC6) : Color.lilac, in: Capsule())
    }
}
struct PackSelectionView: View {
    @Bindable var client: GameClient
    @Bindable var store: PackStore
    @Binding var draft: GameSettings
    @Environment(\.dismiss) private var dismiss
    @State private var adultPrompt = false
    var body: some View {
        Screen(scene: .plain, spacing: 6) {
            Text("Vælg pakker").font(.editorial())
            Text("\(draft.packs.count) valgt").font(.subheadline).padding(.bottom, 4)
            ForEach(Pack.all) { pack in
                if pack.id == "free" || client.owned.contains(pack.id) {
                    Button {
                        if pack.adult && !UserDefaults.standard.bool(forKey: "adult") { adultPrompt = true; return }
                        if draft.packs.contains(pack.id) { draft.packs.removeAll { $0 == pack.id } } else { draft.packs.append(pack.id) }
                    } label: { PackRow(pack: pack, trailing: draft.packs.contains(pack.id) ? "Valgt ✓" : "Vælg") }
                        .buttonStyle(.plain).accessibilityAddTraits(draft.packs.contains(pack.id) ? .isSelected : [])
                } else {
                    NavigationLink { PackDetailView(pack: pack, client: client, store: store) } label: { PackRow(pack: pack, trailing: store.product(pack.id)?.displayPrice ?? "Se pakke") }.buttonStyle(.plain)
                }
            }
            NavigationLink { BundleView(client: client, store: store) } label: {
                HStack { Image("PackReference-launch-bundle").resizable().scaledToFit().frame(width: 66, height: 66).accessibilityHidden(true); VStack(alignment: .leading, spacing: 3) { Text("Se alle seks pakker").font(.headline); Text("Mere at grine af. Mindre at tænke på.").font(.caption) }; Spacer(); Image(systemName: "chevron.right") }.padding(8).settingsSurface()
            }.buttonStyle(.plain)
            Button("Tilbage til spilindstillinger") { dismiss() }.buttonStyle(LoungeButtonStyle()).padding(.top, 8)
        }.alert("Er du fyldt 18 år?", isPresented: $adultPrompt) {
            Button("Ja, jeg er fyldt 18 år") { Task { await client.confirmAdult() } }
            Button("Nej, gå tilbage", role: .cancel) {}
        } message: { Text("Voksenpakker kræver, at du er fyldt 18 år.") }
    }
}
private extension View {
    func settingsSurface() -> some View {
        background(LinearGradient(colors: [.lounge, .ink.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.lilac.opacity(0.3)))
    }
}
struct PackRow: View {
    let pack: Pack
    let trailing: String
    var rowHeight: CGFloat = 72
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack(spacing: 10) {
            Group {
                if pack.id == "free" { Image("PackReference-launch-bundle").resizable().scaledToFit().background(Color.violet.opacity(0.4)) }
                else { Image("PackReference-\(pack.id)").resizable().scaledToFill() }
            }.frame(width: rowHeight, height: typeSize.isAccessibilitySize ? max(90, rowHeight) : rowHeight).clipped().accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(pack.title).font(.body.weight(.bold))
                if let intensity = pack.intensity { IntensityPill(title: intensity) }
                else { Text(pack.id == "danmark" && trailing.contains("✓") ? "Købt" : pack.subtitle).font(.caption).foregroundStyle(Color.cream.opacity(0.8)).lineLimit(typeSize.isAccessibilitySize ? nil : 2) }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
            if trailing == "Valgt ✓" {
                Image(systemName: "checkmark").font(.headline).foregroundStyle(Color.ink).frame(width: 28, height: 28).background(Color.lime, in: RoundedRectangle(cornerRadius: 8)).accessibilityLabel("Valgt")
            } else { Text(trailing).font(.subheadline.weight(.semibold)).multilineTextAlignment(.trailing) }
            if !trailing.contains("✓") && trailing != "Vælg" { Image(systemName: "chevron.right").font(.caption) }
        }.padding(.trailing, 10).frame(maxWidth: .infinity, minHeight: rowHeight).settingsSurface().clipShape(RoundedRectangle(cornerRadius: 11))
    }
}
struct ShopView: View {
    @Bindable var client: GameClient
    @Bindable var store: PackStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Screen(scene: .plain, spacing: 7) {
            Text("Mere på spil").font(.editorial())
            ForEach(Pack.all.filter { $0.id != "free" }) { pack in
                NavigationLink { PackDetailView(pack: pack, client: client, store: store) } label: { PackRow(pack: pack, trailing: client.owned.contains(pack.id) ? "Købt ✓" : store.product(pack.id)?.displayPrice ?? "Se pakke", rowHeight: 86) }.buttonStyle(.plain)
            }
            NavigationLink { BundleView(client: client, store: store) } label: {
                Panel { HStack { Image("PackReference-launch-bundle").resizable().scaledToFit().frame(width: 70, height: 70).accessibilityHidden(true); VStack(alignment: .leading) { Text("Alle seks pakker").font(.headline); Text("Mere at grine af. Mindre at tænke på.").font(.caption) }; Spacer(); Text(store.product("launch-bundle")?.displayPrice ?? "Se mere").font(.headline) } }
            }.buttonStyle(.plain)
            if let route = store.cheapestRoute(owned: client.owned) { Text(route).font(.footnote).foregroundStyle(Color.lilac) }
            Button("Gendan køb") { Task { await store.restore() } }.padding(10)
            if let message = store.message { Text(message).font(.footnote).multilineTextAlignment(.center) }
        }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Luk") { dismiss() } } }
            .task { await store.load(); try? await client.refreshOwnership() }
    }
}
struct PackOwnedView: View {
    let pack: Pack
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Screen(scene: pack.id == "isbryderen" ? .ice : .plain) {
            Text("Pakken er din").font(.editorial(43)).multilineTextAlignment(.center)
            Image(systemName: "checkmark.circle.fill").font(.system(size: 42)).foregroundStyle(Color.lime).accessibilityHidden(true)
            Text(pack.title).font(.editorial(32)).multilineTextAlignment(.center)
            Text("Alle i dit spil kan være med.\nVælg pakken under spilindstillinger.").multilineTextAlignment(.center)
            if pack.id == "isbryderen" {
                Color.clear.frame(height: 380).accessibilityHidden(true)
            } else {
                Image("PackReference-\(pack.id)").resizable().scaledToFit().frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 19)).accessibilityHidden(true)
            }
            Button("Tilbage til pakker") { dismiss() }.buttonStyle(LoungeButtonStyle())
        }
    }
}
struct PackDetailView: View {
    let pack: Pack
    @Bindable var client: GameClient
    @Bindable var store: PackStore
    @State private var adultPrompt = false
    var body: some View {
        Group {
            if client.owned.contains(pack.id) {
                PackOwnedView(pack: pack)
            } else {
                Screen(scene: pack.id == "isbryderen" ? .ice : .plain) {
                    Text(pack.title).font(.editorial(43)).multilineTextAlignment(.center)
                    if let intensity = pack.intensity { IntensityPill(title: intensity) }
                    Text(pack.subtitle).multilineTextAlignment(.center)
                    if pack.id == "isbryderen" { Color.clear.frame(height: 380).accessibilityHidden(true) }
                    else { Image("PackReference-\(pack.id)").resizable().scaledToFit().frame(maxHeight: 300).clipShape(RoundedRectangle(cornerRadius: 19)).accessibilityHidden(true) }
                    Text("Du køber pakken én gang.\nAlle i dit spil kan være med.").multilineTextAlignment(.center)
                    if let product = store.product(pack.id) {
                        Button("Køb for \(product.displayPrice)") {
                            if pack.adult && !UserDefaults.standard.bool(forKey: "adult") { adultPrompt = true }
                            else { Task { await store.buy(pack.id) } }
                        }.buttonStyle(LoungeButtonStyle()).disabled(store.purchasing)
                    } else {
                        Text("Prisen er ikke tilgængelig lige nu.").font(.footnote)
                        Button("Hent pris igen") { Task { await store.load() } }
                    }
                    Text("Engangskøb").font(.caption).foregroundStyle(Color.lilac)
                    Button("Gendan køb") { Task { await store.restore() } }.padding(8)
                    if let message = store.message { Text(message).font(.footnote).multilineTextAlignment(.center) }
                }
            }
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
        Screen(scene: .plain) {
            Text("Alle seks pakker").font(.editorial(40)).multilineTextAlignment(.center)
            Text("Hele holdet. Hele pakken.")
            HStack(spacing: 0) { ForEach(0..<4, id: \.self) { CharacterView(index: $0, size: 88) } }.accessibilityHidden(true)
            HStack(spacing: 6) {
                ForEach(Pack.all.filter { $0.id != "free" }) { pack in
                    Image("PackReference-\(pack.id)").resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 7))
                }
            }.accessibilityHidden(true)
            VStack(spacing: 0) {
                ForEach(Pack.all.filter { $0.id != "free" }) { pack in
                    HStack(spacing: 7) {
                        Text(pack.title).font(.subheadline.weight(.semibold))
                        if let intensity = pack.intensity { IntensityPill(title: intensity) }
                        Spacer(minLength: 0)
                        Text(client.owned.contains(pack.id) ? "Købt ✓" : store.product(pack.id)?.displayPrice ?? "—").font(.subheadline).foregroundStyle(Color.lilac)
                    }.padding(.horizontal, 12).padding(.vertical, 8)
                    if pack.id != "uden-filter" { Divider().padding(.horizontal, 12) }
                }
            }.settingsSurface()
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
    @AppStorage("name") private var name = ""
    @AppStorage("character") private var character = 0
    @AppStorage("sound") private var sound = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("drinking") private var drinking = false
    @State private var adultPrompt = false
    var body: some View {
        Screen(scene: .settings, spacing: 16) {
            Text("Indstillinger").font(.editorial())
            Text("Din profil").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            if client.room == nil || client.room?.phase == "lobby" {
                NavigationLink { ProfileView(client: client) } label: {
                    HStack(spacing: 12) { CharacterView(index: character, size: 62); VStack(alignment: .leading, spacing: 3) { Text(name.isEmpty ? "Din profil" : name).font(.title3.bold()); Text("Rediger din profil").font(.subheadline) }; Spacer(); Image(systemName: "chevron.right") }.padding(10).settingsSurface()
                }.buttonStyle(.plain)
            }
            Text("Lyd og følelse").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 5)
            VStack(spacing: 0) {
                Toggle(isOn: $sound) { Label("Lydeffekter", systemImage: "speaker.wave.2.fill") }.padding(.horizontal, 14).frame(minHeight: 52)
                Divider()
                Toggle(isOn: $haptics) { Label("Vibration", systemImage: "iphone.radiowaves.left.and.right") }.padding(.horizontal, 14).frame(minHeight: 52)
            }.settingsSurface()
            Label("Animationer følger indstillingerne på din iPhone.", systemImage: "info.circle").font(.footnote).foregroundStyle(Color.lilac).frame(maxWidth: .infinity, alignment: .leading)
            Text("Spil").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 5)
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
            VStack(spacing: 0) {
                NavigationLink { RulesView() } label: { preferenceRow("Sådan spiller I", icon: "questionmark.circle") }
                Divider()
                Button { Task { await store.restore() } } label: { preferenceRow("Gendan køb", icon: "square.3.layers.3d") }
                Divider()
                NavigationLink { PrivacyView() } label: { preferenceRow("Privatliv", icon: "shield") }
            }.buttonStyle(.plain).settingsSurface()
            Text("Version 0.1 · Under udvikling").font(.caption).foregroundStyle(Color.lilac)
            if let message = store.message { Text(message).font(.footnote) }
        }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Luk") { dismiss() } } }
            .alert("Er du fyldt 18 år?", isPresented: $adultPrompt) {
                Button("Ja, jeg er fyldt 18 år") { Task { await client.confirmAdult() } }
                Button("Nej, gå tilbage", role: .cancel) {}
            }
    }
    private func preferenceRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 14) { Image(systemName: icon).font(.title3).frame(width: 26); Text(title); Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(.horizontal, 14).frame(minHeight: 52)
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
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Screen(scene: .plain, spacing: 18) {
            Text("Rundens resultat").font(.editorial())
            if let round = room.round {
                Text("Runde \(round.number)")
                Text(round.kind == "personal" ? "\(round.correct ?? 0) af \(round.responseCount ?? 0) svarede ja" : "Det rigtige svar: \(round.correct.flatMap { round.options.indices.contains($0) ? round.options[$0] : nil } ?? "—")").font(.headline).foregroundStyle(Color.lime)
                if typeSize.isAccessibilitySize {
                ForEach(round.results) { result in
                    Panel { VStack(alignment: .leading, spacing: 8) {
                        HStack { CharacterView(index: room.players.first { $0.id == result.playerID }?.character ?? 0, size: 40); Text(room.players.first { $0.id == result.playerID }?.name ?? "Spiller").font(.headline); Spacer(); Text("+\(result.points)").font(.title2.bold()).foregroundStyle(Color.lime) }
                        Text("Svar: \(result.answer.map { round.kind == "personal" ? String($0) : round.options.indices.contains($0) ? round.options[$0] : "—" } ?? "—")")
                        Text("Satsede på: \(room.players.first { $0.id == result.back }?.name ?? "—")")
                        if room.settings.drinking { Text("Valgfrie slurke: \(result.sips.map(String.init) ?? "—")") }
                    }.font(.subheadline) }
                }
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 0) {
                        GridRow {
                            Text("Spiller"); Text("Svar"); Text("Satsede på"); Text("Point")
                            if room.settings.drinking { Text("Valgfrie slurke") }
                        }.font(.caption).foregroundStyle(Color.lilac).padding(.vertical, 14)
                        Divider()
                        ForEach(round.results) { result in
                            GridRow {
                                HStack(spacing: 2) {
                                    CharacterView(index: room.players.first { $0.id == result.playerID }?.character ?? 0, size: 40).accessibilityHidden(true)
                                    Text(room.players.first { $0.id == result.playerID }?.name ?? "Spiller")
                                }
                                Text(result.answer.map { round.kind == "personal" ? String($0) : round.options.indices.contains($0) ? round.options[$0] : "—" } ?? "—")
                                Text(room.players.first { $0.id == result.back }?.name ?? "—")
                                Text("+\(result.points)").font(.headline.bold()).foregroundStyle(Color.lime)
                                if room.settings.drinking { Text(result.sips.map(String.init) ?? "—") }
                            }.font(.subheadline).padding(.vertical, 13)
                            if result.id != round.results.last?.id { Divider() }
                        }
                    }.padding(.horizontal, 8).frame(maxWidth: .infinity).settingsSurface()
                }
                if let fact = round.fact { DisclosureGroup("Fakta og kilde") { VStack(alignment: .leading, spacing: 10) { Text(fact); if let source = round.source, let url = URL(string: source), url.scheme == "https" { Link("Se kilde", destination: url) } }.padding(.vertical, 10) } }
                if room.settings.drinking { Label("Drikkeregler er valgfrie. Du kan altid springe over.", systemImage: "info.circle").font(.callout).padding(.vertical, 12) }
            }
            Spacer(minLength: 36)
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
