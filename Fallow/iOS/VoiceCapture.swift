import AVFoundation
import Observation
import Speech

/// On-device transcription with a smoothed input level for the orb.
/// If permission or recognition is unavailable, `unavailable` is set and the flow falls back to typing or the demo line.
@MainActor
@Observable
final class VoiceCapture {
    var transcript = ""
    var isRunning = false
    var unavailable = false

    @ObservationIgnored var onLevel: ((Double) -> Void)?
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var level = 0.0

    func start() async {
        transcript = ""
        unavailable = false
        guard let recognizer, recognizer.isAvailable, await Self.authorize() else {
            unavailable = true
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.request = request

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 else {
                unavailable = true
                return
            }
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tap(request: request) { [weak self] value in
                Task { @MainActor in self?.receive(value) }
            })
            engine.prepare()
            try engine.start()

            task = recognizer.recognitionTask(with: request, resultHandler: Self.results { [weak self] text in
                Task { @MainActor in self?.transcript = text }
            })
            isRunning = true
        } catch {
            unavailable = true
            stop()
        }
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
        }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        isRunning = false
        level = 0
        onLevel?(0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func receive(_ value: Double) {
        guard isRunning else { return }
        level += (value - level) * 0.35
        onLevel?(level)
    }

    private static func authorize() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
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
        _ text: @escaping @Sendable (String) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, _ in
            guard let result else { return }
            text(result.bestTranscription.formattedString)
        }
    }
}
