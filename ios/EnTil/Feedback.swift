import AVFoundation
import UIKit

@MainActor final class Feedback {
    static let shared = Feedback()
    private var player: AVAudioPlayer?
    func play(_ event: String) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "haptics") as? Bool ?? true {
            if event == "reveal" { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            else { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.65) }
        }
        guard defaults.object(forKey: "sound") as? Bool ?? true,
              let url = Bundle.main.url(forResource: event, withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            player = try AVAudioPlayer(contentsOf: url); player?.volume = 0.45; player?.play()
        } catch { /* Sound is optional; game state must remain unaffected. */ }
    }
}
