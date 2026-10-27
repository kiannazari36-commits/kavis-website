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

    /// Starts listening in the language of the app; `onText` gets the whole text so far (it grows while speaking),
    /// `onEnd` tells why it stopped when nothing useful was heard.
    @MainActor func start(lang: Lang, onText: @escaping (String) -> Void, onEnd: @escaping (Failure?) -> Void) async {
        guard !listening else { return }
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
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.heard = true
                    onText(result.bestTranscription.formattedString)
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
        guard listening else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        listening = false
    }

    @MainActor private func finish() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request = nil
        task = nil
        listening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
