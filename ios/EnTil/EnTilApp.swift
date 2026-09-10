import SwiftUI

@main struct EnTilApp: App {
    @State private var client = GameClient()
    @State private var store = PackStore()
    var body: some Scene {
        WindowGroup {
            RootView(client: client, store: store)
                .preferredColorScheme(.dark).tint(.lime)
                .environment(\.locale, Locale(identifier: "da_DK"))
        }
    }
}
struct RootView: View {
    @Bindable var client: GameClient
    @Bindable var store: PackStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var sheet: HomeSheet?
    @State private var joining = false
    @State private var leaving = false
    enum HomeSheet: String, Identifiable { case profile, settings, packs, setup, rules; var id: String { rawValue } }
    var body: some View {
        NavigationStack {
            Group {
                if let room = client.room { RoomView(client: client, store: store, room: room, showSetup: { sheet = .setup }, showProfile: { sheet = .profile }) }
                else if joining { JoinView(client: client, close: { joining = false }) }
                else { HomeView(client: client, show: { sheet = $0 }, join: { joining = true }) }
            }
            .toolbar {
                if client.room != nil {
                    ToolbarItem(placement: .topBarLeading) { Button("Forlad", systemImage: "chevron.left") { leaving = true }.labelStyle(.iconOnly) }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Sådan spiller I", systemImage: "questionmark.circle") { sheet = .rules }
                            Button("Dine indstillinger", systemImage: "gearshape") { sheet = .settings }
                            if client.room?.isHost == true && client.room?.phase != "lobby" { Button("Afslut kampen", role: .destructive) { leaving = true } }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("Spilmenu")
                    }
                }
            }
            .overlay(alignment: .top) {
                if client.reconnecting {
                    HStack { ProgressView(); Text("Forbinder igen · Tiden løber videre").font(.caption) }
                        .padding(12).background(Color.lounge, in: Capsule()).padding(.top, 8)
                        .accessibilityElement(children: .combine)
                }
            }
            .sheet(item: $sheet) { selected in
                NavigationStack {
                    switch selected {
                    case .profile: ProfileView(client: client)
                    case .settings: PreferencesView(client: client, store: store)
                    case .packs: ShopView(client: client, store: store)
                    case .setup: if let room = client.room { SetupView(client: client, store: store, original: room.settings) }
                    case .rules: RulesView()
                    }
                }.presentationDragIndicator(.visible).preferredColorScheme(.dark).tint(.lime)
            }
            .fullScreenCover(isPresented: $client.needsAdult) { AdultView(client: client) }
            .alert("Der er lige noget", isPresented: Binding(get: { client.problem != nil }, set: { if !$0 { client.problem = nil } })) {
                Button("OK") { client.problem = nil }
            } message: { Text(client.problem ?? "") }
            .confirmationDialog("Vil du forlade spillet?", isPresented: $leaving, titleVisibility: .visible) {
                Button("Forlad spillet", role: .destructive) { Task { await client.leave() } }
                if client.room?.isHost == true && client.room?.phase != "lobby" {
                    Button("Afslut kampen for alle", role: .destructive) { Task { await client.command(.init(type: "end")) } }
                }
                Button("Bliv her", role: .cancel) {}
            } message: { Text("Din plads bliver gemt, så du kan vende tilbage fra denne iPhone.") }
        }
        .task {
            #if DEBUG
            if let fixture = ProcessInfo.processInfo.environment["ENTIL_SCREENSHOT_FIXTURE"] {
                client.loadFixture(fixture); return
            }
            #endif
            await client.restoreSeat()
            await store.start(client: client)
        }
        .onChange(of: scenePhase) { _, phase in
            #if DEBUG
            if ProcessInfo.processInfo.environment["ENTIL_SCREENSHOT_FIXTURE"] != nil { return }
            #endif
            if phase == .active, client.room != nil { client.connect() }
            if phase == .background { client.disconnect() }
        }
        .onChange(of: client.ageDeclined) { _, declined in
            if declined { joining = true; sheet = nil }
        }
        .onChange(of: client.room?.phase) { before, after in
            if after == "reveal" && before != "reveal" { Feedback.shared.play("reveal") }
            if after == "countdown" { Feedback.shared.play("ready") }
        }
    }
}
struct HomeView: View {
    @Bindable var client: GameClient
    let show: (RootView.HomeSheet) -> Void
    let join: () -> Void
    @AppStorage("name") private var name = ""
    @AppStorage("character") private var character = 0
    @AppStorage("adult") private var adult = false
    @AppStorage("drinking") private var drinking = false
    var body: some View {
        Screen {
            HStack { Spacer(); Button("Indstillinger", systemImage: "gearshape") { show(.settings) }.labelStyle(.iconOnly).frame(width: 44, height: 44) }
            VStack(spacing: 0) {
                Text("En til?").font(.editorial(76)).rotationEffect(.degrees(-5)).accessibilityAddTraits(.isHeader)
                Capsule().fill(Color.lime).frame(width: 145, height: 7).rotationEffect(.degrees(-7))
            }.padding(.bottom, -40).zIndex(1)
            LoungeIllustration().frame(height: 280).padding(.horizontal, -22)
            Text("Gode venner.\nDårlige svar.\nEndnu en runde?").font(.editorial(21)).italic().multilineTextAlignment(.center).padding(.top, -35)
            Button { show(.profile) } label: {
                Panel { HStack { CharacterView(index: character, size: 42); Text(name.isEmpty ? "Vælg navn og figur" : name); Spacer(); Image(systemName: "chevron.right") } }
            }.buttonStyle(.plain)
            VStack(spacing: 12) {
                Button("Opret spil") {
                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { show(.profile) }
                    else { Task { await client.create(name: name, character: character, adult: adult, drinking: drinking) } }
                }.buttonStyle(LoungeButtonStyle()).disabled(client.busy)
                Button("Deltag i spil", action: join).buttonStyle(LoungeButtonStyle(primary: false))
                Button("Se pakker ›") { show(.packs) }.padding(10)
                if UserDefaults.standard.string(forKey: "roomID") != nil {
                    Button("Tilbage til dit spil") { Task { await client.restoreSeat() } }.font(.footnote)
                }
            }
        }
    }
}
struct JoinView: View {
    @Bindable var client: GameClient
    let close: () -> Void
    @AppStorage("name") private var name = ""
    @AppStorage("character") private var character = 0
    @AppStorage("adult") private var adult = false
    @AppStorage("drinking") private var drinking = false
    @State private var code = ""
    @State private var step = 0
    @FocusState private var focused: Bool
    var body: some View {
        Screen {
            HStack { Button("Tilbage", systemImage: "chevron.left") { if step > 0 { step -= 1 } else { close() } }.labelStyle(.iconOnly).frame(width: 44, height: 44); Spacer(); if step > 0 { Text(code).font(.headline.monospaced()).tracking(4) } }
            Text(step == 0 ? "Deltag i spil" : step == 1 ? "Hvad skal vi kalde dig?" : "Find din figur").font(.editorial()).multilineTextAlignment(.center)
            Text(step == 0 ? "Indtast koden fra værten." : step == 1 ? "Dit navn bliver vist til de andre." : "Vælg den, der ligner dit humør.").multilineTextAlignment(.center)
            if step < 2 { CharacterView(index: step == 0 ? 1 : character, size: 115) }
            if step == 0 {
                TextField("KODE", text: Binding(get: { code }, set: { value in
                    code = String(value.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(4))
                })).font(.system(size: 40, weight: .black, design: .monospaced)).tracking(9).multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.asciiCapable).submitLabel(.continue)
                    .padding(20).background(Color.lounge, in: RoundedRectangle(cornerRadius: 18)).focused($focused)
                    .onSubmit { if code.count == 4 { findRoom() } }.accessibilityLabel("Spilkode, fire bogstaver eller tal")
                Button("Find spil") { findRoom() }.buttonStyle(LoungeButtonStyle()).disabled(code.count != 4 || client.busy)
            } else if step == 1 {
                Panel { VStack(alignment: .leading) { Text("Navn").font(.caption); TextField("Dit navn", text: $name).textContentType(.nickname).submitLabel(.continue).onSubmit { if validName { step = 2; focused = false } }.focused($focused) } }
                Button(name.isEmpty ? "Vælg figur" : "Fortsæt som \(name)") { step = 2; focused = false }.buttonStyle(LoungeButtonStyle()).disabled(!validName)
            } else {
                CharacterPicker(selection: $character, seats: client.joinPreview?.seats ?? [])
                Button("Deltag i spil") { Task { await client.join(code: code, name: name, character: character, adult: adult, drinking: drinking) } }
                    .buttonStyle(LoungeButtonStyle()).disabled(client.busy)
                Text("Hvis figuren allerede er valgt, kan du vælge en anden.").font(.footnote).foregroundStyle(Color.lilac)
            }
        }.task { focused = true; if client.ageDeclined { step = 0; client.ageDeclined = false } }
            .onChange(of: client.ageDeclined) { _, declined in
                if declined { step = 0; focused = true; client.ageDeclined = false }
            }
    }
    private func findRoom() {
        Task {
            if await client.findRoom(code: code) {
                if client.joinPreview?.characters.contains(where: { $0.character == character }) == true {
                    character = (0..<12).first { index in !(client.joinPreview?.characters.contains { $0.character == index } ?? false) } ?? character
                }
                step = 1
            }
        }
    }
    private var validName: Bool { (1...24).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count) }
}
struct CharacterPicker: View {
    @Binding var selection: Int
    let seats: [Seat]
    var me: String?
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 12) {
            ForEach(0..<12, id: \.self) { index in
                let occupant = seats.first { $0.character == index && $0.id != me }
                Button { selection = index } label: {
                    VStack(spacing: 2) {
                        CharacterView(index: index, size: 72)
                        if let occupant { Text(occupant.name).font(.caption).lineLimit(2) }
                        else if selection == index { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lime) }
                    }.frame(maxWidth: .infinity, minHeight: 96).padding(5)
                        .background(Color.lounge, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(selection == index ? Color.lime : Color.lilac.opacity(0.2), lineWidth: selection == index ? 2 : 1))
                        .opacity(occupant == nil ? 1 : 0.5)
                }.buttonStyle(.plain).disabled(occupant != nil).accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }
    }
}
struct ProfileView: View {
    @Bindable var client: GameClient
    @Environment(\.dismiss) private var dismiss
    @State private var name = UserDefaults.standard.string(forKey: "name") ?? ""
    @State private var character = UserDefaults.standard.integer(forKey: "character")
    var body: some View {
        Screen {
            Text("Dit navn. Din figur.").font(.editorial())
            TextField("Dit navn", text: $name).textContentType(.nickname).padding(18).background(Color.lounge, in: RoundedRectangle(cornerRadius: 15))
            CharacterPicker(selection: $character, seats: client.room?.players ?? [], me: client.room?.me)
            Button("Gem profil") {
                Task {
                    if client.room != nil { await client.command(.init(type: "identity", name: name, character: character)) }
                    if client.problem == nil {
                        UserDefaults.standard.set(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "name")
                        UserDefaults.standard.set(character, forKey: "character"); dismiss()
                    }
                }
            }.buttonStyle(LoungeButtonStyle()).disabled(client.busy || !(1...24).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count))
        }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Luk") { dismiss() } } }
    }
}
struct AdultView: View {
    @Bindable var client: GameClient
    var body: some View {
        Screen {
            Text("En til?").font(.editorial(64))
            if let code = client.room?.code { Text(code).font(.title.monospaced().bold()).tracking(5) }
            Text("Er du fyldt 18 år?").font(.editorial()).multilineTextAlignment(.center)
            Text("Dette spil indeholder voksenindhold eller valgfrie drikkeregler.").multilineTextAlignment(.center)
            LoungeIllustration()
            Text("Vi husker dit svar på denne iPhone.").font(.footnote).foregroundStyle(Color.lilac)
            Button("Ja, jeg er fyldt 18 år") { Task { await client.confirmAdult() } }.buttonStyle(LoungeButtonStyle())
            Button("Nej, gå tilbage") { Task { await client.declineAdult() } }.buttonStyle(LoungeButtonStyle(primary: false))
            Text("Du kan stadig deltage i spil uden voksenindhold og drikkeregler.").font(.footnote).multilineTextAlignment(.center)
        }.preferredColorScheme(.dark).interactiveDismissDisabled()
    }
}
