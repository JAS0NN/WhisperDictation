import Foundation
import AVFoundation

class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?

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
        if !recorder!.record() {
            throw NSError(domain: "AudioRecorder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"])
        }
        print("🎙️ Recording started: \(outputURL.lastPathComponent)")
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        recorder = nil
        print("🎙️ Recording stopped")
        return outputURL
    }
}
