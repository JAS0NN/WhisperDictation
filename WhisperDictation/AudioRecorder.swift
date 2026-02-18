import Foundation
import AVFoundation

class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?
    private var timer: Timer?
    private var silenceDuration: TimeInterval = 0
    private let silenceThreshold: Float = -50.0 // dB
    
    // Callbacks
    var onSilenceDetected: (() -> Void)?
    var onAudioLevelUpdate: ((Float) -> Void)?

    func startRecording() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("whisper_recording_\(UUID().uuidString).wav")
        self.outputURL = outputURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder?.isMeteringEnabled = true // Important for averagePower
        if !recorder!.record() {
            throw NSError(domain: "AudioRecorder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"])
        }
        print("🎙️ Recording started: \(outputURL.lastPathComponent)")
        startMonitoring()
    }

    private func startMonitoring() {
        silenceDuration = 0.0
        // Check audio levels every 0.05 seconds (20Hz) - faster for UI
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkAudioLevel()
        }
    }

    private func checkAudioLevel() {
        guard let recorder = recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        
        let power = recorder.averagePower(forChannel: 0)
        
        // 1. UI Metering Broadcast
        // Normalize -60dB...-10dB to 0.0...1.0
        let minDb: Float = -60.0
        let maxDb: Float = -10.0
        let normalized = max(0.0, min(1.0, (power - minDb) / (maxDb - minDb)))
        onAudioLevelUpdate?(normalized)
        
        // 2. VAD Logic
        if power < silenceThreshold {
            silenceDuration += 0.05
        } else {
            silenceDuration = 0.0
        }

        if silenceDuration > 2.0 { // 2 seconds of silence
            print("🤫 Silence detected, stopping recording...")
            timer?.invalidate()
            timer = nil
            onSilenceDetected?()
        }
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        recorder = nil
        print("🎙️ Recording stopped")
        return outputURL
    }
}
