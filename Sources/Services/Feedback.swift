import UIKit
import AVFoundation

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

    /// The chime of a right answer.
    static func dingCorrect() {
        guard soundsEnabled else { return }
        AnswerSounds.shared.play(.correct)
    }
    /// The buzz of a wrong one.
    static func dingWrong() {
        guard soundsEnabled else { return }
        AnswerSounds.shared.play(.wrong)
    }

    /// How long the chime needs before a voice can start reading the answer back
    /// without the two talking over each other.
    static var chimeGap: Double { soundsEnabled ? 0.75 : 0 }
}

/// The two sounds an answer makes, loaded once and kept ready.
///
/// These used to be system sounds, which iOS plays through the ringer: with the
/// silent switch on they vanished, and with it off they were a faint click. The
/// course voice plays through the media channel, so the chime now does too — at
/// the same volume as everything else the lesson says.
final class AnswerSounds {
    enum Sound: String, CaseIterable {
        case correct, wrong
    }

    static let shared = AnswerSounds()

    private var players: [Sound: AVAudioPlayer] = [:]

    private init() {
        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[sound] = player
        }
    }

    func play(_ sound: Sound) {
        guard let player = players[sound] else { return }
        prepareSession()
        // a second answer before the first chime is over starts it again
        player.currentTime = 0
        player.play()
    }

    /// Makes sure the sound comes out of the speaker, silent switch or not — the
    /// same way the course voice does. A session already set up for the microphone
    /// is left alone: a pronunciation check has just finished with it, and pulling
    /// the category from under the recogniser is how audio stops working.
    private func prepareSession() {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playback && session.category != .playAndRecord {
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        }
        try? session.setActive(true, options: [])
    }
}
