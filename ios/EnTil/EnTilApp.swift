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
                #if DEBUG
                if let route = specialFixtureRoute { VisualFixtureView(name: route, client: client, store: store) }
                else { liveContent }
                #else
                liveContent
                #endif
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if client.reconnecting { ReconnectingView { leaving = true } }
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
                client.loadFixture(fixture); if fixture == "reconnect" { client.reconnecting = true }; return
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
    @ViewBuilder private var liveContent: some View {

                if let room = client.room {
                    VStack(spacing: 0) {
                        HStack {
                            Button("Forlad", systemImage: "chevron.left") { leaving = true }.labelStyle(.iconOnly)
                            Spacer()
                            Menu {
                                Button("Sådan spiller I") { sheet = .rules }
                                Button("Dine indstillinger") { sheet = .settings }
                                if room.isHost { Button("Spilindstillinger") { sheet = .setup } }
                            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 32) }
                        }.font(.title3).foregroundStyle(Color.cream).buttonStyle(.plain).padding(.horizontal, 18).frame(height: 32)
                        RoomView(client: client, store: store, room: room, showSetup: { sheet = .setup }, showProfile: { sheet = .profile })
                    }.background { SceneBackground() }
                }
                else if joining { JoinView(client: client, close: { joining = false }) }
                else { HomeView(client: client, show: { sheet = $0 }, join: { joining = true }) }

    }
    #if DEBUG
    private var specialFixtureRoute: String? {
        guard let name = ProcessInfo.processInfo.environment["ENTIL_SCREENSHOT_FIXTURE"],
              ["join", "name", "characters", "code-error", "settings", "setup", "pack-selection", "shop", "pack-detail", "bundle", "adult", "results", "pack-owned"].contains(name) else { return nil }
        return name
    }
    #endif

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
        Screen(scene: .home, spacing: 10) {
            HStack { Spacer(); Button("Indstillinger", systemImage: "gearshape") { show(.settings) }.labelStyle(.iconOnly).font(.title2).frame(width: 36, height: 32) }.foregroundStyle(Color.cream)
            BrandLogo().frame(height: 132).padding(.horizontal, 22)
            Spacer(minLength: 166)
            Text("Gode venner.\nDårlige svar.\nEndnu en runde?").font(.custom("Fraunces-Regular", size: 17, relativeTo: .body)).italic().multilineTextAlignment(.center).lineSpacing(0)
            Button { show(.profile) } label: {
                Panel { HStack(spacing: 10) { CharacterView(index: character, size: 32); Text(name.isEmpty ? "Vælg navn og figur" : name).font(.subheadline); Spacer(); Image(systemName: "chevron.right") } }
            }.buttonStyle(.plain)
            Button("Opret spil") {
                if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { show(.profile) }
                else { Task { await client.create(name: name, character: character, adult: adult, drinking: drinking) } }
            }.buttonStyle(LoungeButtonStyle()).disabled(client.busy)
            Button("Deltag i spil", action: join).buttonStyle(LoungeButtonStyle(primary: false))
            Button("Se pakker ›") { show(.packs) }.font(.footnote).padding(.vertical, 8).foregroundStyle(Color.cream)
            if UserDefaults.standard.string(forKey: "roomID") != nil {
                Button("Tilbage til dit spil") { Task { await client.restoreSeat() } }.font(.footnote)
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
    @State private var codeError: Bool
    init(client: GameClient, close: @escaping () -> Void, initialStep: Int = 0, initialCode: String = "", initialError: Bool = false) {
        self.client = client; self.close = close
        _step = State(initialValue: initialStep); _code = State(initialValue: initialCode); _codeError = State(initialValue: initialError)
    }
    var body: some View {
        Screen(scene: step < 2 ? .lounge : .plain, spacing: 10) {
            HStack { Button("Tilbage", systemImage: "chevron.left") { if step > 0 { step -= 1 } else { close() } }.labelStyle(.iconOnly).frame(width: 44, height: 44); Spacer(); if step > 0 { Text(code).font(.headline.monospaced()).tracking(4) } }
            Text(step == 0 ? "Deltag i spil" : step == 1 ? "Hvad skal vi kalde dig?" : "Find din figur").font(.editorial()).multilineTextAlignment(.center)
            Text(step == 0 ? "Indtast koden fra værten." : step == 1 ? "Dit navn bliver vist til de andre." : "Vælg den, der ligner dit humør.").multilineTextAlignment(.center)
            if step < 2 { CharacterView(index: 1, size: 96).padding(.bottom, -18).zIndex(1) }
            if step == 0 {
                ZStack {
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { index in
                            let letters = Array(code)
                            Text(index < letters.count ? String(letters[index]) : " ")
                                .font(.system(size: 37, weight: .black, design: .rounded))
                                .frame(maxWidth: .infinity).frame(height: 74)
                                .background(Color.ink.opacity(0.8), in: RoundedRectangle(cornerRadius: 11))
                                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(focused && index == min(code.count, 3) ? Color.lime : Color.lilac.opacity(0.3), lineWidth: focused && index == min(code.count, 3) ? 2 : 1))
                        }
                    }.accessibilityHidden(true)
                    TextField("KODE", text: Binding(get: { code }, set: { value in
                        code = String(value.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(4))
                    })).foregroundStyle(.clear).tint(.clear).opacity(0.02)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.asciiCapable).submitLabel(.continue)
                        .focused($focused).onSubmit { if code.count == 4 { findRoom() } }
                        .accessibilityLabel("Spilkode, fire bogstaver eller tal")
                        .frame(height: 74)
                }.padding(13).background(Color.lounge, in: RoundedRectangle(cornerRadius: 18)).onTapGesture { focused = true }
                if codeError { Label("Vi kunne ikke finde et spil med den kode.", systemImage: "exclamationmark.circle.fill").font(.footnote).foregroundStyle(Color(hex: 0xFF9188)) }
                Button(codeError ? "Prøv igen" : "Find spil") { findRoom() }.buttonStyle(LoungeButtonStyle()).disabled(code.count != 4 || client.busy)
            } else if step == 1 {
                Panel { VStack(alignment: .leading) { Text("Navn").font(.caption); TextField("Dit navn", text: $name).textContentType(.nickname).submitLabel(.continue).onSubmit { if validName { step = 2; focused = false } }.focused($focused) } }
                Button("Vælg figur") { step = 2; focused = false }.buttonStyle(LoungeButtonStyle()).disabled(!validName)
            } else {
                Text(name).font(.subheadline).padding(.horizontal, 18).padding(.vertical, 5).background(Color.violet, in: Capsule())
                Text("Figurer med navn er allerede valgt.").font(.footnote)
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
                step = 1; codeError = false
            } else { codeError = true; client.problem = nil }
        }
    }
    private var validName: Bool { (1...24).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count) }
}
struct CharacterPicker: View {
    @Binding var selection: Int
    let seats: [Seat]
    var me: String?
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
            ForEach(0..<12, id: \.self) { index in
                let occupant = seats.first { $0.character == index && $0.id != me }
                Button { selection = index } label: {
                    VStack(spacing: 2) {
                        CharacterView(index: index, size: 68)
                        if let occupant { Text(occupant.name).font(.caption).lineLimit(2) }
                        else if selection == index { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lime) }
                    }.frame(maxWidth: .infinity, minHeight: 83).padding(5)
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
        Screen(scene: .home) {
            BrandLogo().frame(height: 108)
            if let code = client.room?.code { CodePlaque(code: code) }
            Text("Er du fyldt 18 år?").font(.editorial()).multilineTextAlignment(.center)
            Text("Dette spil indeholder voksenindhold eller valgfrie drikkeregler.").multilineTextAlignment(.center)
            Spacer(minLength: 170)
            Text("Vi husker dit svar på denne iPhone.").font(.footnote).foregroundStyle(Color.lilac)
            Button("Ja, jeg er fyldt 18 år") { Task { await client.confirmAdult() } }.buttonStyle(LoungeButtonStyle())
            Button("Nej, gå tilbage") { Task { await client.declineAdult() } }.buttonStyle(LoungeButtonStyle(primary: false))
            Text("Du kan stadig deltage i spil uden voksenindhold og drikkeregler.").font(.footnote).multilineTextAlignment(.center)
        }.preferredColorScheme(.dark).interactiveDismissDisabled()
    }
}

struct ReconnectingView: View {
    let leave: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 0) {
                CharacterView(index: 2, size: 95).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 30).padding(.bottom, -28).zIndex(1)
                Panel {
                    VStack(spacing: 24) {
                        Text("Forbindelsen blev afbrudt").font(.editorial(30)).multilineTextAlignment(.center)
                        Text("Vi prøver at forbinde dig igen.").multilineTextAlignment(.center)
                        ProgressView().controlSize(.large).tint(.lilac).padding(8)
                        Text("Tiden løber videre.").font(.footnote)
                        Divider().overlay(Color.lilac.opacity(0.25))
                        Button("Forlad spillet", action: leave).underline().foregroundStyle(Color.lilac)
                    }.padding(.vertical, 20)
                }
            }.padding(.horizontal, 34).frame(maxWidth: 420)
        }.foregroundStyle(Color.cream)
    }
}
