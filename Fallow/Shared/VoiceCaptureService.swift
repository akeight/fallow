import AVFoundation
import Observation
import Speech

/// Why voice could not produce a thought. Every case still leaves typing open.
enum VoiceCaptureError: Equatable {
    case microphoneDenied
    case speechDenied
    case recognizerUnavailable
    case noSpeech
    case failed

    var message: String {
        switch self {
        case .microphoneDenied: "Microphone access is off. You can type it instead."
        case .speechDenied: "Speech recognition is off. You can type it instead."
        case .recognizerUnavailable: "Voice isn’t available right now. You can type it instead."
        case .noSpeech: "Nothing came through. Try again, or type it."
        case .failed: "The recording was interrupted. You can type it instead."
        }
    }
}

enum VoiceCaptureState: Equatable {
    case idle
    case requestingPermission
    case listening
    case transcribing
    case complete(String)
    case failed(VoiceCaptureError)
}

/// Microphone, speech permission, recognition, and a smoothed input level for the orb.
/// Shared by iPhone and Mac. Views call `start`, `stop`, and `cancel`; no audio code lives in them.
/// Recognition stays on the device when it can, and otherwise uses Apple's speech service.
@MainActor
@Observable
final class VoiceCaptureService {
    private(set) var state: VoiceCaptureState = .idle
    private(set) var partialTranscript = ""
    private(set) var level = 0.0

    /// Mirrors `level` for the orb without making it observe this service.
    @ObservationIgnored var onLevel: ((Double) -> Void)?
    /// Recognition ended on its own while listening (silence, or Apple's per-request limit).
    /// The owner finishes through its usual stop path so the text so far is kept.
    @ObservationIgnored var onEndedEarly: (() -> Void)?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var finalText: String?
    @ObservationIgnored private var recognitionEnded = false
    @ObservationIgnored private var finalWaiter: CheckedContinuation<Void, Never>?
    @ObservationIgnored private var onDevice = false
    /// The recognizer itself could not run, as opposed to hearing nothing.
    @ObservationIgnored private var recognizerFailed = false
    /// Callbacks from a replaced recognition task are ignored.
    @ObservationIgnored private var generation = 0

    var isListening: Bool { state == .listening }

    /// Asking, listening, or turning speech into text. Starting again is ignored while busy.
    var isBusy: Bool {
        switch state {
        case .requestingPermission, .listening, .transcribing: true
        default: false
        }
    }

    var error: VoiceCaptureError? {
        if case .failed(let error) = state { return error }
        return nil
    }

    /// The last few lines' worth of what is being heard. Older words fall away so listening stays calm.
    var recentTranscript: String {
        let words = partialTranscript.split(separator: " ")
        return words.suffix(18).joined(separator: " ")
    }

    func start() async {
        guard !isBusy else { return }
        partialTranscript = ""
        finalText = nil
        recognitionEnded = false
        recognizerFailed = false
        state = .requestingPermission

        guard let recognizer, recognizer.isAvailable else {
            fail(.recognizerUnavailable)
            return
        }
        guard await Self.speechAuthorized() else {
            fail(.speechDenied)
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            fail(.microphoneDenied)
            return
        }
        // Cancelled while a permission prompt was up.
        guard state == .requestingPermission else { return }

        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            guard engine.inputNode.outputFormat(forBus: 0).sampleRate > 0 else {
                teardown()
                fail(.recognizerUnavailable)
                return
            }
            beginRecognition(with: recognizer, onDevice: recognizer.supportsOnDeviceRecognition)
            engine.prepare()
            try engine.start()
            state = .listening
        } catch {
            teardown()
            fail(.failed)
        }
    }

    /// Stops listening, waits briefly for the final words, and returns the full transcript.
    /// Returns nil and moves to `.failed` when nothing usable came through.
    func stop() async -> String? {
        guard state == .listening else { return nil }
        state = .transcribing
        stopAudio()
        if !recognitionEnded {
            await waitForFinal(seconds: 2)
        }
        task = nil
        request = nil
        deactivateSession()

        let text = (finalText ?? partialTranscript).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            fail(recognizerFailed ? .recognizerUnavailable : .noSpeech)
            return nil
        }
        state = .complete(text)
        return text
    }

    func cancel() {
        guard state != .idle else { return }
        task?.cancel()
        teardown()
        partialTranscript = ""
        state = .idle
    }

    /// Clears a finished or failed attempt so the next screen starts quiet.
    func reset() {
        guard !isBusy else { return }
        partialTranscript = ""
        state = .idle
    }

    // MARK: Private

    /// A fresh request and tap. The engine keeps running when this replaces an earlier task.
    private func beginRecognition(with recognizer: SFSpeechRecognizer, onDevice: Bool) {
        generation += 1
        let current = generation
        self.onDevice = onDevice
        recognitionEnded = false

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = onDevice
        self.request = request

        let input = engine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0), block: Self.tap(request: request) { [weak self] value in
            Task { @MainActor in self?.receive(level: value) }
        })

        task = recognizer.recognitionTask(with: request, resultHandler: Self.results(
            text: { [weak self] text, isFinal in
                Task { @MainActor in
                    guard self?.generation == current else { return }
                    self?.receive(text: text, isFinal: isFinal)
                }
            },
            ended: { [weak self] unavailable in
                Task { @MainActor in
                    guard self?.generation == current else { return }
                    self?.recognitionDidEnd(unavailable: unavailable)
                }
            }
        ))
    }

    private func fail(_ error: VoiceCaptureError) {
        state = .failed(error)
        setLevel(0)
    }

    private func receive(level value: Double) {
        guard state == .listening else { return }
        setLevel(level + (value - level) * 0.35)
    }

    private func setLevel(_ value: Double) {
        level = value
        onLevel?(value)
    }

    private func receive(text: String, isFinal: Bool) {
        guard isBusy else { return }
        partialTranscript = text
        if isFinal {
            finalText = text
            recognitionDidEnd()
        }
    }

    private func recognitionDidEnd(unavailable: Bool = false) {
        guard !recognitionEnded else { return }
        // A device can report on-device support without the model installed. Before any words
        // have arrived, retry once with Apple's speech service instead of reporting silence.
        if onDevice, state == .listening, partialTranscript.isEmpty, let recognizer, recognizer.isAvailable {
            task?.cancel()
            beginRecognition(with: recognizer, onDevice: false)
            return
        }
        if unavailable, partialTranscript.isEmpty { recognizerFailed = true }
        recognitionEnded = true
        resumeFinalWaiter()
        if state == .listening {
            onEndedEarly?()
        }
    }

    private func waitForFinal(seconds: Double) async {
        await withCheckedContinuation { continuation in
            finalWaiter = continuation
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                self?.resumeFinalWaiter()
            }
        }
    }

    private func resumeFinalWaiter() {
        finalWaiter?.resume()
        finalWaiter = nil
    }

    private func stopAudio() {
        if engine.isRunning {
            engine.stop()
        }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        setLevel(0)
    }

    private func teardown() {
        stopAudio()
        task = nil
        request = nil
        resumeFinalWaiter()
        deactivateSession()
    }

    private func deactivateSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private static func speechAuthorized() async -> Bool {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        return status == .authorized
    }

    /// Built outside the main actor: the audio engine calls it on its own thread.
    nonisolated private static func tap(
        request: SFSpeechAudioBufferRecognitionRequest,
        level: @escaping @Sendable (Double) -> Void
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
            guard let samples = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }
            var sum: Float = 0
            for index in 0..<count {
                sum += samples[index] * samples[index]
            }
            let rms = sqrt(sum / Float(count))
            let decibels = 20 * log10(max(rms, 0.000_01))
            level(Double(min(1, max(0, (decibels + 50) / 40))))
        }
    }

    nonisolated private static func results(
        text: @escaping @Sendable (String, Bool) -> Void,
        ended: @escaping @Sendable (_ unavailable: Bool) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            if let result {
                text(result.bestTranscription.formattedString, result.isFinal)
            }
            if let error {
                // The speech framework's own domain means the recognizer failed to run (for example,
                // no model on this device, as in the Simulator). Silence comes from a different domain.
                ended((error as NSError).domain == "kLSRErrorDomain")
            }
        }
    }
}
