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
    static func editorial(_ size: CGFloat = 32) -> Font { .custom("Fraunces-Regular", size: size, relativeTo: .largeTitle).weight(.bold) }
}
struct LoungeButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var primary = true
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 24).padding(.vertical, 15).padding(.horizontal, 16)
            .foregroundStyle(primary ? Color.ink : Color.cream)
            .background(primary ? Color.lime : Color.violet, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(primary ? Color.white.opacity(0.15) : Color.lilac.opacity(0.25)))
            .scaleEffect(configuration.isPressed && !reducedMotion ? 0.975 : 1)
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.85 : 1)
            .animation(reducedMotion ? nil : .spring(response: 0.25, dampingFraction: 1), value: configuration.isPressed)
    }
}
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [.lounge, .ink.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(Color.lilac.opacity(0.25)))
    }
}
struct Screen<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView { VStack(spacing: 20) { content }.padding(.horizontal, 22).padding(.vertical, 18).frame(maxWidth: 560).frame(maxWidth: .infinity) }
            .scrollDismissesKeyboard(.interactively).background(Color.ink).foregroundStyle(Color.cream)
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
        Canvas { context, bounds in
            let i = min(max(index, 0), 11)
            let scale = min(bounds.width, bounds.height) / 100
            context.scaleBy(x: scale, y: scale)
            let color = Color(hex: Self.colors[i])
            func fill(_ path: Path, _ value: Color) {
                if value == color { context.fill(path, with: .linearGradient(Gradient(colors: [color, color.opacity(0.82)]), startPoint: CGPoint(x: 25, y: 15), endPoint: CGPoint(x: 75, y: 90))) }
                else { context.fill(path, with: .color(value)) }
            }
            func stroke(_ path: Path, _ value: Color, _ width: CGFloat = 4) { context.stroke(path, with: .color(value), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)) }
            func polygon(_ points: [CGPoint]) -> Path { Path { p in p.addLines(points); p.closeSubpath() } }
            // Limbs stay independent of the silhouette, making future pose animation local.
            var legs = Path(); legs.move(to: CGPoint(x: 38, y: 73)); legs.addLine(to: CGPoint(x: 34, y: 90)); legs.addLine(to: CGPoint(x: 27, y: 89)); legs.move(to: CGPoint(x: 61, y: 74)); legs.addLine(to: CGPoint(x: 64, y: 90)); legs.addLine(to: CGPoint(x: 71, y: 90)); stroke(legs, color, 7)
            var body: Path
            switch i {
            case 0:
                body = Path(roundedRect: CGRect(x: 22, y: 12, width: 58, height: 70), cornerRadius: 28)
                fill(body, color); fill(Path(roundedRect: CGRect(x: 44, y: 66, width: 16, height: 23), cornerRadius: 8), .ink)
            case 2:
                body = polygon([.init(x: 25, y: 12), .init(x: 79, y: 24), .init(x: 69, y: 52), .init(x: 86, y: 49), .init(x: 66, y: 80), .init(x: 49, y: 69), .init(x: 40, y: 83), .init(x: 35, y: 55), .init(x: 13, y: 59), .init(x: 30, y: 39)]); fill(body, color)
            case 3:
                body = Path { p in
                    p.move(to: .init(x: 50, y: 13))
                    p.addCurve(to: .init(x: 85, y: 65), control1: .init(x: 70, y: 8), control2: .init(x: 87, y: 48))
                    p.addCurve(to: .init(x: 15, y: 65), control1: .init(x: 91, y: 84), control2: .init(x: 8, y: 88))
                    p.addCurve(to: .init(x: 50, y: 13), control1: .init(x: 12, y: 47), control2: .init(x: 30, y: 13))
                    p.closeSubpath()
                }; fill(body, color)
            case 4, 9:
                for n in 0..<6 { let angle = Double(n) * .pi / 3; fill(Path(ellipseIn: CGRect(x: 33 + cos(angle)*21, y: 29 + sin(angle)*21, width: 32, height: 32)), color) }
                fill(Path(ellipseIn: CGRect(x: 27, y: 25, width: 45, height: 45)), color)
            case 5, 10:
                let tips = i == 5 ? 5 : 10
                let points = (0..<(tips*2)).map { n -> CGPoint in let angle = Double(n) * .pi / Double(tips) - .pi/2; let radius = n.isMultiple(of: 2) ? 39.0 : (i == 5 ? 20.0 : 28.0); return CGPoint(x: 50 + cos(angle)*radius, y: 47 + sin(angle)*radius) }
                fill(polygon(points), color)
            case 6:
                body = Path { p in p.move(to: .init(x: 50, y: 80)); p.addCurve(to: .init(x: 16, y: 30), control1: .init(x: 5, y: 48), control2: .init(x: 10, y: 14)); p.addCurve(to: .init(x: 50, y: 27), control1: .init(x: 27, y: 5), control2: .init(x: 46, y: 15)); p.addCurve(to: .init(x: 84, y: 30), control1: .init(x: 57, y: 9), control2: .init(x: 84, y: 11)); p.addCurve(to: .init(x: 50, y: 80), control1: .init(x: 99, y: 47), control2: .init(x: 62, y: 72)); p.closeSubpath() }; fill(body, color)
            case 7: fill(polygon([.init(x: 29, y: 15), .init(x: 67, y: 10), .init(x: 85, y: 39), .init(x: 68, y: 77), .init(x: 32, y: 79), .init(x: 14, y: 44)]), color)
            case 8:
                body = Path { p in p.move(to: .init(x: 50, y: 9)); p.addCurve(to: .init(x: 50, y: 80), control1: .init(x: 106, y: 57), control2: .init(x: 84, y: 80)); p.addCurve(to: .init(x: 50, y: 9), control1: .init(x: 2, y: 83), control2: .init(x: 1, y: 51)); p.closeSubpath() }; fill(body, color)
            case 11: fill(Path(roundedRect: CGRect(x: 27, y: 10, width: 49, height: 71), cornerRadius: 7), color)
            default: fill(Path(ellipseIn: CGRect(x: 17, y: i == 3 ? 17 : 13, width: 68, height: 67)), color)
            }
            var arms = Path(); arms.move(to: .init(x: 22, y: 48)); arms.addQuadCurve(to: .init(x: 11, y: i == 1 ? 22 : 65), control: .init(x: 4, y: 52)); arms.move(to: .init(x: 78, y: 48)); arms.addQuadCurve(to: .init(x: 90, y: i == 1 ? 21 : 61), control: .init(x: 97, y: 51)); stroke(arms, color, 5)
            for x: CGFloat in [39, 61] { fill(Path(ellipseIn: CGRect(x: x-6, y: 34, width: 13, height: 16)), .cream); fill(Path(ellipseIn: CGRect(x: x-3, y: 38, width: 8, height: 10)), .ink) }
            if i == 0 || i == 2 { var lids = Path(); lids.move(to: .init(x: 32, y: 37)); lids.addLine(to: .init(x: 47, y: 33)); lids.move(to: .init(x: 54, y: 37)); lids.addLine(to: .init(x: 68, y: 33)); stroke(lids, color, 9) }
            if i == 8 { fill(Path(roundedRect: CGRect(x: 28, y: 33, width: 21, height: 13), cornerRadius: 5), .ink); fill(Path(roundedRect: CGRect(x: 53, y: 33, width: 21, height: 13), cornerRadius: 5), .ink); var bridge = Path(); bridge.move(to: .init(x: 45, y: 36)); bridge.addLine(to: .init(x: 56, y: 36)); stroke(bridge, .ink, 3) }
            var brows = Path(); brows.move(to: .init(x: 34, y: 28)); brows.addQuadCurve(to: .init(x: 45, y: 26), control: .init(x: 40, y: 21)); brows.move(to: .init(x: 56, y: 26)); brows.addQuadCurve(to: .init(x: 66, y: 27), control: .init(x: 60, y: 21)); stroke(brows, .ink, 2.5)
            if i == 3 {
                var hands = Path(); hands.move(to: .init(x: 27, y: 51)); hands.addQuadCurve(to: .init(x: 49, y: 55), control: .init(x: 29, y: 84)); hands.move(to: .init(x: 73, y: 55)); hands.addQuadCurve(to: .init(x: 51, y: 55), control: .init(x: 65, y: 84)); stroke(hands, .ink, 3)
            }
            var smile = Path(); smile.move(to: .init(x: 42, y: 56)); smile.addQuadCurve(to: .init(x: 59, y: 54), control: .init(x: 53, y: 66)); stroke(smile, .ink, 3)
        }.frame(width: size, height: size).accessibilityLabel(Self.names[min(max(index, 0), 11)])
    }
}
struct SeatCard: View {
    let seat: Seat
    let host: Bool
    var selected = false
    var body: some View {
        VStack(spacing: 5) {
            CharacterView(index: seat.character, size: 83).accessibilityHidden(true)
            if host { Label("Vært", systemImage: "crown.fill").font(.caption.bold()).foregroundStyle(Color.lime) }
            else if seat.ready { Label("Klar", systemImage: "checkmark").font(.caption.bold()).foregroundStyle(Color.lime) }
            else if seat.away { Text("Sidder over").font(.caption).foregroundStyle(Color.lilac) }
            else if seat.late { Text("Næste spil").font(.caption).foregroundStyle(Color.lilac) }
            Text(seat.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity).padding(10).background(Color.lounge, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.lime : Color.lilac.opacity(0.3), lineWidth: selected ? 2 : 1))
            .accessibilityElement(children: .combine)
    }
}

struct NumberChoice: View {
    let number: Int
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(String(number)).font(.title.bold().monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: 72)
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
