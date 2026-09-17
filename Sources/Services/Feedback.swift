import UIKit
import AudioToolbox

enum Feedback {
    static var hapticsEnabled = true
    static var soundsEnabled = true

    static func success() {
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func failure() {
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    static func tap() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func pop() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func celebrate() {
        guard hapticsEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { g.impactOccurred(intensity: 0.7) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { g.impactOccurred(intensity: 1.0) }
    }
    static func dingCorrect() {
        guard soundsEnabled else { return }
        AudioServicesPlaySystemSound(1103)
    }
    static func dingWrong() {
        guard soundsEnabled else { return }
        AudioServicesPlaySystemSound(1053)
    }
}
