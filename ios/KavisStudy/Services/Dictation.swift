import AVFoundation
import Speech
import Observation

/// Voice for the assistant: the student speaks, Apple's recognizer on this phone writes the words into the text box
/// (on-device only, so the sound never leaves the phone; CLAUDE.md). Tap the microphone again to stop.
@Observable
final class Dictation {
    enum Failure { case denied, empty, unsupported }

    private(set) var listening = false
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var heard = false
    /// Hands-free ("Sürekli dinle"): stops by itself after a pause in speech, or when nobody speaks at all.
    private var silence: Task<Void, Never>?
    static let pauseAfterSpeech: Double = 1.5
    static let quietLimit: Double = 8

    /// Starts listening in the language of the app; `onText` gets the whole text so far (it grows while speaking),
    /// `onEnd` tells why it stopped when nothing useful was heard. With `autoStop` it ends by itself
    /// (`pauseAfterSpeech` seconds after the last word, or `quietLimit` seconds with no word at all).
    @MainActor func start(lang: Lang, autoStop: Bool = false, onText: @escaping (String) -> Void, onEnd: @escaping (Failure?) -> Void) async {
        guard !listening else { return }
        // Simulator tests (Apple's on-device recognizer does not run there): `kavis.fakeSpeech` is "heard" word by word.
        if let fake = MockFlag.value("fakeSpeech") { return fakeListen(fake, onText: onText, onEnd: onEnd) }
        guard await Transcriber.authorize(), await AVAudioApplication.requestRecordPermission() else { return onEnd(.denied) }
        guard let recognizer = SFSpeechRecognizer(locale: Transcriber.locale(lang.rawValue)), recognizer.supportsOnDeviceRecognition else { return onEnd(.unsupported) }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.request = request
        heard = false
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in request.append(buffer) }
        engine.prepare()
        guard (try? engine.start()) != nil else { return onEnd(.unsupported) }
        listening = true
        if autoStop { wait(Self.quietLimit) }
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.heard = true
                    onText(result.bestTranscription.formattedString)
                    if autoStop && !result.isFinal { self.wait(Self.pauseAfterSpeech) }
                    if result.isFinal { self.finish(); onEnd(nil) }
                } else if error != nil {
                    let silent = !self.heard
                    self.finish()
                    onEnd(silent ? .empty : nil)
                }
            }
        }
    }

    /// Stops listening; the recognizer still delivers the last words.
    @MainActor func stop() {
        silence?.cancel()
        guard listening else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        listening = false
    }

    /// Stops listening when nothing new is heard for `seconds` (every new word starts the wait again).
    @MainActor private func wait(_ seconds: Double) {
        silence?.cancel()
        silence = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled { self?.stop() }
        }
    }

    @MainActor private func fakeListen(_ text: String, onText: @escaping (String) -> Void, onEnd: @escaping (Failure?) -> Void) {
        listening = true
        silence = Task { @MainActor [weak self] in
            var said: [Substring] = []
            for word in text.split(separator: " ") {
                try? await Task.sleep(for: .milliseconds(300))
                guard let self, self.listening else { return }
                said.append(word)
                onText(said.joined(separator: " "))
            }
            try? await Task.sleep(for: .seconds(Self.pauseAfterSpeech))
            guard let self, self.listening else { return }
            self.listening = false
            onEnd(text.isEmpty ? .empty : nil)
        }
    }

    @MainActor private func finish() {
        silence?.cancel()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request = nil
        task = nil
        listening = false
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        // Back to playing, so the answer read aloud right after is heard (the recording category stays silent).
        try? session.setCategory(.playback, mode: .spokenAudio)
    }
}
