import SwiftUI

extension Color {
    init(hex: UInt) { self.init(red: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255) }
    static let ink = Color(hex: 0x10101E)
    static let lounge = Color(hex: 0x211E36)
    static let violet = Color(hex: 0x4B3B76)
    static let cream = Color(hex: 0xFFF6E7)
    static let lime = Color(hex: 0xDBF877)
    static let lilac = Color(hex: 0xC4A9F4)
}
extension Font {
    static func editorial(_ size: CGFloat = 32) -> Font { .custom("EnTilHeadings-Bold", size: size, relativeTo: .largeTitle) }
}
enum SceneArtwork: String {
    case lounge, lobby, settings, adult, home, question, backing, privateRound, waiting, paused, guess, board, finale, ice, plain
}
struct SceneBackground: View {
    var scene: SceneArtwork = .lounge
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.ink
                Image("Scene-" + scene.rawValue).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(y: scene == .adult ? geometry.size.height * 0.12 : 0)
                    .opacity(typeSize.isAccessibilitySize ? 0.25 : 1)
                    .clipped()
                if scene == .settings {
                    LinearGradient(stops: [.init(color: .clear, location: 0.14), .init(color: .ink, location: 0.34)], startPoint: .top, endPoint: .bottom)
                }
            }
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}
struct BrandLogo: View {
    var body: some View {
        Image("BrandLogo").resizable().scaledToFit().accessibilityLabel("En til?").accessibilityAddTraits(.isHeader)
    }
}
struct LoungeButtonStyle: ButtonStyle {
    var primary = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.headline, design: .rounded).weight(.heavy)).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 28).padding(.vertical, 16).padding(.horizontal, 12)
            .foregroundStyle(primary ? Color.ink : Color.cream)
            .background(LinearGradient(colors: primary ? [Color(hex: 0xDEF989), .lime, Color(hex: 0xE6FF95)] : [Color(hex: 0x453765), Color(hex: 0x362B53), Color(hex: 0x504073)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(primary ? Color.lime.opacity(0.7) : Color.lilac.opacity(0.3)))
            .scaleEffect(configuration.isPressed && !reducedMotion ? 0.975 : 1)
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.85 : 1)
            .animation(reducedMotion ? nil : .spring(response: 0.25, dampingFraction: 1), value: configuration.isPressed)
    }
}
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(13).frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [Color(hex: 0x232036).opacity(0.97), Color(hex: 0x161523).opacity(0.96)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.lilac.opacity(0.26)))
    }
}
struct Screen<Content: View>: View {
    var scene: SceneArtwork = .lounge
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: spacing) { content }
                    .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 12)
                    .frame(maxWidth: 560).frame(minHeight: geometry.size.height, alignment: .top).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively)
        }.background { SceneBackground(scene: scene) }.foregroundStyle(Color.cream)
    }
}
struct CodePlaque: View {
    let code: String
    var body: some View {
        VStack(spacing: 5) {
            Text("Spilkode").font(.caption)
            HStack(spacing: 8) {
                Text(code).font(.system(size: 55, weight: .black, design: .rounded)).tracking(7)
                Image(systemName: "doc.on.doc").font(.caption)
            }.padding(.horizontal, 18).padding(.vertical, 4)
                .background(Color.ink.opacity(0.75), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.lilac.opacity(0.35)))
        }.padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: .infinity)
            .background(Color.lounge.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
    }
}
struct Choice: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title).font(.headline).multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? Color.lime : Color.lilac)
            }.padding(18).frame(minHeight: 58).frame(maxWidth: .infinity)
                .background(selected ? Color.lime.opacity(0.1) : Color.lounge, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(selected ? Color.lime : Color.lilac.opacity(0.3), lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct LoungeIllustration: View {
    var body: some View {
        Image("Lounge").resizable().scaledToFit().accessibilityHidden(true)
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12), .init(color: .black, location: 0.92), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
    }
}
struct CharacterView: View {
    let index: Int
    var size: CGFloat = 80
    static let names = ["Den afslappede", "Den begejstrede", "Den skeptiske", "Den generte", "Kløveren", "Stjernen", "Hjertet", "Den kantede", "Den cool", "Blomsten", "Solen", "Den høje"]
    static let colors: [UInt] = [0xD9F477, 0xFF978B, 0xB999EC, 0xFFC18E, 0x71D4C8, 0xF7D66B, 0xF19CC6, 0x9CD967, 0x7EABEF, 0xBB9ADD, 0xFFBB55, 0xEF9BC7]
    var body: some View {
        Image("Character-\(min(max(index, 0), 11))").resizable().scaledToFit()
            .frame(width: size, height: size).accessibilityLabel(Self.names[min(max(index, 0), 11)])
    }
}
struct SeatCard: View {
    let seat: Seat
    let host: Bool
    var selected = false
    var own = false
    var compact = false
    var tall = false
    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                CharacterView(index: seat.character, size: compact ? 75 : 111).accessibilityHidden(true)
                if host { Image(systemName: "crown.fill").font(.system(size: 19)).foregroundStyle(Color(hex: 0xFFD466)).rotationEffect(.degrees(12)).offset(x: -7, y: -7) }
            }
            if host || own || seat.ready {
                Text(host ? "Vært" : own ? "Dig" : "✓ Klar").font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.ink).padding(.horizontal, 14).padding(.vertical, 2)
                    .background(own && !host ? Color.lilac : Color.lime, in: Capsule()).padding(.top, -12)
            }
            Text(seat.name).font(.caption).multilineTextAlignment(.center).lineLimit(2)
            if seat.away { Text("Væk").font(.caption2).foregroundStyle(Color.lilac) }
            if seat.late { Text("Næste spil").font(.caption2).foregroundStyle(Color.lilac) }
        }.frame(maxWidth: .infinity, minHeight: tall ? 190 : nil).padding(.vertical, 7).padding(.horizontal, 4)
            .background(LinearGradient(colors: [.lounge.opacity(0.86), .ink.opacity(0.88)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(selected ? Color.lime : Color.lilac.opacity(0.3), lineWidth: selected ? 2 : 1))
            .overlay(alignment: .topTrailing) { if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lime).font(.title3).padding(7) } }
            .accessibilityElement(children: .combine)
    }
}

struct NumberChoice: View {
    let number: Int
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(String(number)).font(.editorial(42)).monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 100)
                .foregroundStyle(selected ? Color.ink : Color.cream)
                .background(selected ? Color.lime : Color.lounge, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(selected ? Color.lime : Color.lilac.opacity(0.3), lineWidth: selected ? 2 : 1))
                .overlay(alignment: .topTrailing) {
                    if selected { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(Color.ink).padding(6) }
                }
        }.buttonStyle(.plain)
            .accessibilityLabel("\(number) ja-svar")
            .accessibilityIdentifier("guess-\(number)")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct PersonalChoice: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.editorial(29)).frame(maxWidth: .infinity, minHeight: 100)
                .background(selected ? Color.lime.opacity(0.1) : Color.lounge.opacity(0.95), in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(selected ? Color.lime : Color.lilac.opacity(0.3), lineWidth: selected ? 2 : 1))
                .overlay(alignment: .topTrailing) { if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lime).font(.title2).padding(9) } }
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
