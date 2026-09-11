import SwiftUI

struct WindingBoard: View {
    let room: RoomSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    private let spaceHeight: CGFloat = 60
    private var maximum: Int { max(room.settings.finish, room.players.map(\.score).max() ?? 0) }
    private var boardHeight: CGFloat { CGFloat(maximum + 1) * spaceHeight + 84 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if textSize.isAccessibilitySize {
                    VStack(spacing: 14) {
                        ForEach(room.players.sorted { $0.score > $1.score }) { seat in
                            HStack {
                                CharacterView(index: seat.character, size: 44).accessibilityHidden(true)
                                Text(seat.name)
                                Spacer()
                                Text("\(seat.score) point").foregroundStyle(Color.lime)
                            }.accessibilityElement(children: .combine)
                                .accessibilityIdentifier(seat.id == room.me ? "board-own-position" : "board-player-\(seat.id)")
                                .id(seat.id)
                        }
                    }.padding()
                } else {
                    GeometryReader { geometry in
                        let centerX = geometry.size.width * 0.46
                        let amplitude = min(geometry.size.width * 0.24, 90)
                        Canvas { context, _ in
                            // Each tile has its own shallow front edge. The narrower distant
                            // tiles keep the ribbon's perspective around the current player.
                            for space in (0...maximum).reversed() {
                                let tile = tilePath(space: space, centerX: centerX, amplitude: amplitude)
                                let depth = tile.offsetBy(dx: 0, dy: 7)
                                context.fill(depth, with: .color(Color(hex: 0x302447)))
                                let center = point(at: Double(space), centerX: centerX, amplitude: amplitude)
                                context.fill(tile, with: .linearGradient(
                                    Gradient(colors: [Color(hex: 0x78629D), Color(hex: 0x59457C), Color(hex: 0x695388)]),
                                    startPoint: CGPoint(x: center.x - 55, y: center.y - 24),
                                    endPoint: CGPoint(x: center.x + 48, y: center.y + 28)))
                                context.stroke(tile, with: .color(space == room.settings.finish ? Color.lime.opacity(0.8) : Color.lilac.opacity(0.4)), lineWidth: 1)
                            }
                        }.accessibilityHidden(true)
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 42)
                            ForEach(Array((0...maximum).reversed()), id: \.self) { space in
                                let occupants = room.players.filter { $0.score == space }
                                let x = point(at: Double(space), centerX: centerX, amplitude: amplitude).x - geometry.size.width / 2
                                ZStack {
                                    Text(space == room.settings.finish ? "MÅL" : "\(space)")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                                        .foregroundStyle(space == room.settings.finish ? Color.lime : Color.cream.opacity(0.7))
                                        .rotationEffect(.degrees(-5))
                                        .offset(x: x - (occupants.isEmpty ? 0 : 25), y: 2)
                                        .accessibilityHidden(true)
                                    if !occupants.isEmpty {
                                        VStack(spacing: 1) {
                                            HStack(alignment: .bottom, spacing: 2) {
                                                ForEach(occupants.prefix(4)) { seat in boardPlayer(seat, crowded: occupants.count > 2) }
                                            }
                                            if occupants.count > 4 {
                                                HStack(alignment: .bottom, spacing: 2) {
                                                    ForEach(occupants.dropFirst(4)) { seat in boardPlayer(seat, crowded: true) }
                                                }
                                            }
                                        }.offset(x: occupantOffset(x, count: occupants.count, width: geometry.size.width), y: -13)
                                            .accessibilityElement(children: .ignore)
                                            .accessibilityLabel("Felt \(space): \(occupants.map(\.name).joined(separator: ", "))")
                                            .accessibilityIdentifier(occupants.contains { $0.id == room.me } ? "board-own-position" : "board-space-\(space)")
                                    }
                                }.frame(maxWidth: .infinity).frame(height: spaceHeight).id(space)
                            }
                            Color.clear.frame(height: 42)
                        }
                    }.frame(height: boardHeight)
                }
            }.defaultScrollAnchor(.bottom)
                .onAppear {
                    if textSize.isAccessibilitySize { proxy.scrollTo(room.me, anchor: .center) }
                    else { proxy.scrollTo(room.ownSeat?.score ?? 0, anchor: .center) }
                }
                .onChange(of: room.ownSeat?.score) { _, score in
                    withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 1)) {
                        if textSize.isAccessibilitySize { proxy.scrollTo(room.me, anchor: .center) }
                        else { proxy.scrollTo(score ?? 0, anchor: .center) }
                    }
                }
        }
    }

    private func point(at progress: Double, centerX: CGFloat, amplitude: CGFloat) -> CGPoint {
        CGPoint(x: centerX + sin(progress * 0.95) * amplitude, y: boardHeight - 72 - CGFloat(progress) * spaceHeight)
    }

    private func halfWidth(at progress: Double) -> CGFloat {
        let distance = progress - Double(room.ownSeat?.score ?? 0)
        return 49 - CGFloat(min(max(distance, -3), 5)) * 2.2
    }

    private func tilePath(space: Int, centerX: CGFloat, amplitude: CGFloat) -> Path {
        var points: [CGPoint] = []
        for sample in 0...12 {
            let progress = Double(space) - 0.48 + Double(sample) * 0.96 / 12
            let center = point(at: progress, centerX: centerX, amplitude: amplitude)
            points.append(CGPoint(x: center.x - halfWidth(at: progress), y: center.y))
        }
        for sample in (0...12).reversed() {
            let progress = Double(space) - 0.48 + Double(sample) * 0.96 / 12
            let center = point(at: progress, centerX: centerX, amplitude: amplitude)
            points.append(CGPoint(x: center.x + halfWidth(at: progress), y: center.y))
        }
        return Path { path in path.addLines(points); path.closeSubpath() }
    }

    private func occupantOffset(_ x: CGFloat, count: Int, width: CGFloat) -> CGFloat {
        let halfGroup = CGFloat(min(count, 4)) * (count > 2 ? 25 : 31)
        let limit = max(0, width / 2 - halfGroup - 8)
        return min(max(x + 23, -limit), limit)
    }

    private func boardPlayer(_ seat: Seat, crowded: Bool) -> some View {
        VStack(spacing: -5) {
            CharacterView(index: seat.character, size: crowded ? 30 : 47).accessibilityHidden(true)
            Text(seat.name).font(.system(size: crowded ? 9 : 10, weight: .semibold))
                .lineLimit(1).padding(.horizontal, 6).padding(.vertical, 3)
                .foregroundStyle(seat.id == room.me ? Color.ink : Color.cream)
                .background(seat.id == room.me ? Color.lime : Color.violet, in: Capsule())
        }.frame(width: crowded ? 48 : 60)
    }
}
