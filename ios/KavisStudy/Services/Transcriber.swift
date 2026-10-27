import AVFoundation
import Speech

/// Turns a lecture recording into timestamped text on this phone (Apple's speech recognition, on-device only, so the
/// sound never leaves the phone; CLAUDE.md). Long recordings are read in parts of one minute, which keeps the
/// recognizer within its limits and gives a progress value.
enum Transcriber {
    enum Failure: Error { case denied, unsupported, unreadable }

    /// Length of one part that is read at a time, in seconds.
    static let chunk: Double = 60

    /// The recognizer's language for a lesson language ("tr" → Turkish, …).
    static func locale(_ lang: String?) -> Locale {
        switch lang {
        case "en": Locale(identifier: "en-US")
        case "fa": Locale(identifier: "fa-IR")
        case "ar": Locale(identifier: "ar-SA")
        default: Locale(identifier: "tr-TR")
        }
    }

    /// Asks for the speech recognition permission once.
    static func authorize() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
    }

    /// Length of a sound file in seconds (0 when it cannot be read).
    static func duration(_ url: URL) -> Double {
        guard let f = try? AVAudioFile(forReading: url) else { return 0 }
        return Double(f.length) / f.processingFormat.sampleRate
    }

    /// The whole recording as lines; `progress` gets 0–100 while it is read.
    static func transcribe(_ url: URL, lang: String?, progress: @escaping @MainActor (Int) -> Void) async throws -> [RecordingAPI.Segment] {
        guard await authorize() else { throw Failure.denied }
        guard let recognizer = SFSpeechRecognizer(locale: locale(lang)), recognizer.supportsOnDeviceRecognition else { throw Failure.unsupported }
        guard let file = try? AVAudioFile(forReading: url) else { throw Failure.unreadable }
        let format = file.processingFormat
        let rate = format.sampleRate
        let perChunk = AVAudioFrameCount(chunk * rate)
        var words: [Word] = []
        var at: AVAudioFramePosition = 0
        while at < file.length {
            try Task.checkCancellation()
            let offset = Double(at) / rate
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = false
            request.addsPunctuation = true
            var left = min(AVAudioFramePosition(perChunk), file.length - at)
            file.framePosition = at
            while left > 0 {
                let n = AVAudioFrameCount(min(left, 16_384))
                guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n) else { throw Failure.unreadable }
                try file.read(into: buf, frameCount: n)
                if buf.frameLength == 0 { break }
                request.append(buf)
                left -= AVAudioFramePosition(buf.frameLength)
            }
            request.endAudio()
            guard let found = await recognize(recognizer, request) else { throw Failure.unsupported }
            words += found.map { Word(start: $0.start + offset, end: $0.end + offset, text: $0.text) }
            at += AVAudioFramePosition(perChunk)
            let pct = Int((Double(min(at, file.length)) / Double(max(file.length, 1)) * 100).rounded())
            await progress(pct)
        }
        return lines(words)
    }

    struct Word: Equatable {
        let start: Double
        let end: Double
        let text: String
    }

    /// One part's words with their times; an empty list when nothing was understood, nil when the recognizer cannot start. A part that gets no answer in
    /// 2 minutes is given up (the recognizer can stall), so a long recording never hangs.
    private static func recognize(_ recognizer: SFSpeechRecognizer, _ request: SFSpeechAudioBufferRecognitionRequest) async -> [Word]? {
        final class Box: @unchecked Sendable {
            let lock = NSLock()
            var done = false
            var task: SFSpeechRecognitionTask?
            /// True only for the first caller, so the answer is given once.
            func finish() -> Bool { lock.lock(); defer { lock.unlock() }; if done { return false }; done = true; return true }
        }
        let box = Box()
        return await withCheckedContinuation { c in
            box.task = recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    if box.finish() { c.resume(returning: result.bestTranscription.segments.map { Word(start: $0.timestamp, end: $0.timestamp + $0.duration, text: $0.substring) }) }
                } else if let error {
                    // "No speech detected" in a silent part ends here too (empty part); a recognizer that cannot start
                    // (no language files on the device, or the simulator) is reported.
                    let broken = (error as NSError).domain == "kLSRErrorDomain" && (error as NSError).code == 300
                    if box.finish() { c.resume(returning: broken ? nil : []) }
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 120) {
                if box.finish() { box.task?.cancel(); c.resume(returning: [] as [Word]?) }
            }
        }
    }

    /// Words joined into lines: a new line after a pause of over 1.5 seconds, after a sentence end, or at 15 seconds.
    static func lines(_ words: [Word]) -> [RecordingAPI.Segment] {
        var out: [RecordingAPI.Segment] = []
        var cur: [Word] = []
        func flush() {
            guard let first = cur.first, let last = cur.last else { return }
            let text = cur.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { out.append(RecordingAPI.Segment(start: first.start.rounded(), end: max(first.start, last.end).rounded(), text: text)) }
            cur = []
        }
        for w in words {
            if let last = cur.last, w.start - last.end > 1.5 || w.end - cur[0].start > 15 { flush() }
            cur.append(w)
            if let c = w.text.last, ".?!".contains(c), w.end - cur[0].start > 4 { flush() }
        }
        flush()
        return out
    }
}

/// A live recording in class (AVAudioRecorder, M4A). It goes on while the screen is off (background audio mode).
@Observable
final class LiveRecorder {
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    /// Seconds recorded, nil when not recording.
    var seconds: Int?

    var isRecording: Bool { seconds != nil }

    /// Asks for the microphone and starts; false when the microphone is not allowed.
    @MainActor func start() async -> Bool {
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard allowed else { return false }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .spokenAudio)
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("lecture-\(UUID().uuidString.prefix(8)).m4a")
            let r = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 32_000,
            ])
            guard r.record() else { return false }
            recorder = r
            seconds = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self, let r = self.recorder else { return }
                self.seconds = Int(r.currentTime)
            }
            return true
        } catch {
            return false
        }
    }

    /// Stops and returns the file.
    @MainActor func stop() -> URL? {
        timer?.invalidate()
        timer = nil
        guard let r = recorder else { seconds = nil; return nil }
        r.stop()
        recorder = nil
        seconds = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return r.url
    }
}
