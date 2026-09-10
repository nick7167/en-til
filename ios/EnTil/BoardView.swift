import SwiftUI

struct WindingBoard: View {
    let room: RoomSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    private var maximum: Int { max(room.settings.finish, room.players.map(\.score).max() ?? 0) }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if textSize.isAccessibilitySize {
                    VStack(spacing: 14) {
                        ForEach(room.players.sorted { $0.score > $1.score }) { seat in
                            HStack { CharacterView(index: seat.character, size: 44).accessibilityHidden(true); Text(seat.name); Spacer(); Text("\(seat.score) point").foregroundStyle(Color.lime) }.accessibilityElement(children: .combine)
                        }
                    }.padding()
                } else {
                    GeometryReader { geometry in
                        let height = CGFloat(maximum + 2) * 84
                        let centerX = geometry.size.width * 0.46
                        let amplitude = min(geometry.size.width * 0.19, 75)
                        Canvas { context, _ in
                            var ribbon = Path()
                            for step in 0...(maximum * 12 + 12) {
                                let progress = Double(step) / 12
                                let point = CGPoint(x: centerX + sin(progress * 0.47) * amplitude, y: height - 70 - progress * 84)
                                if step == 0 { ribbon.move(to: point) } else { ribbon.addLine(to: point) }
                            }
                            context.stroke(ribbon, with: .color(Color.lilac.opacity(0.45)), style: StrokeStyle(lineWidth: 104, lineCap: .round))
                            context.stroke(ribbon, with: .linearGradient(Gradient(colors: [Color(hex: 0x685292), .violet, Color(hex: 0x75629F)]), startPoint: .zero, endPoint: CGPoint(x: geometry.size.width, y: height)), style: StrokeStyle(lineWidth: 101, lineCap: .round))
                            for space in 0...maximum {
                                let x = centerX + sin(Double(space) * 0.47) * amplitude
                                let y = height - 70 - CGFloat(space) * 84
                                var divider = Path(); divider.move(to: CGPoint(x: x-44, y: y+32)); divider.addLine(to: CGPoint(x: x+44, y: y+22))
                                context.stroke(divider, with: .color(Color.lilac.opacity(0.4)), lineWidth: 1)
                            }
                        }.accessibilityHidden(true)
                        ForEach(0...maximum, id: \.self) { space in
                            let occupants = room.players.filter { $0.score == space }
                            let x = centerX + sin(Double(space) * 0.47) * amplitude
                            let y = height - 70 - CGFloat(space) * 84
                            Text(space == room.settings.finish ? "MÅL" : "\(space)")
                                .font(.headline.monospacedDigit()).foregroundStyle(space == room.settings.finish ? Color.lime : Color.cream.opacity(0.7))
                                .position(x: x, y: y + (occupants.isEmpty ? 0 : 25)).accessibilityHidden(true)
                            if !occupants.isEmpty {
                                VStack(spacing: 0) {
                                    HStack(spacing: -9) { ForEach(occupants.prefix(4)) { seat in CharacterView(index: seat.character, size: 38).accessibilityHidden(true) } }
                                    if occupants.count > 4 { HStack(spacing: -9) { ForEach(occupants.dropFirst(4)) { seat in CharacterView(index: seat.character, size: 32).accessibilityHidden(true) } } }
                                    Text(occupants.count == 1 ? occupants[0].name : "\(occupants.count) spillere")
                                        .font(.caption2.bold()).foregroundStyle(occupants.contains { $0.id == room.me } ? Color.ink : Color.cream)
                                        .padding(.horizontal, 9).padding(.vertical, 3).background(occupants.contains { $0.id == room.me } ? Color.lime : Color.ink, in: Capsule())
                                }.position(x: x + 24, y: y-10)
                                    .accessibilityElement(children: .ignore).accessibilityLabel("Felt \(space): \(occupants.map(\.name).joined(separator: ", "))")
                            }
                            Color.clear.frame(width: 1, height: 1).position(x: x, y: y).id(space)
                        }
                    }.frame(height: CGFloat(maximum + 2) * 84)
                }
            }.background(LinearGradient(colors: [.ink, .lounge, .ink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .onAppear { proxy.scrollTo(room.ownSeat?.score ?? 0, anchor: .center) }
                .onChange(of: room.ownSeat?.score) { _, score in withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 1)) { proxy.scrollTo(score ?? 0, anchor: .center) } }
        }
    }
}
