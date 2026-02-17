import Foundation
import SwiftUI

enum DictationStatus: Equatable {
    case idle
    case recording
    case transcribing
    case error(String)
}

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var status: DictationStatus = .idle
    @Published var statusMessage: String = "Initializing..."

    private var audioRecorder: AudioRecorder?
    private let transcriber = WhisperTranscriber()
    private let textInserter = TextInserter()

    var statusIcon: String {
        switch status {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "ellipsis.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    var statusColor: Color {
        switch status {
        case .idle: return .green
        case .recording: return .red
        case .transcribing: return .orange
        case .error: return .yellow
        }
    }

    var statusLabel: String {
        switch status {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .transcribing: return "Transcribing..."
        case .error: return "Error"
        }
    }

    func loadModelFromBundle() {
        if let modelPath = Bundle.main.url(forResource: "ggml-breeze-asr25", withExtension: "bin", subdirectory: "models") {
            Task {
                await transcriber.loadModel(path: modelPath.path())
                statusMessage = "Ready — Hold Left Ctrl + Left Option to record"
            }
        } else {
            statusMessage = "⚠️ No model found. Add ggml-*.bin to Resources/models."
        }
    }

    func startRecording() {
        guard status == .idle, transcriber.isModelLoaded else { return }
        status = .recording
        statusMessage = "🎙️ Recording... (release keys to transcribe, ESC to cancel)"

        do {
            audioRecorder = AudioRecorder()
            try audioRecorder?.startRecording()
        } catch {
            status = .error(error.localizedDescription)
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    func stopRecordingAndTranscribe() async {
        guard status == .recording, let audioRecorder = audioRecorder else { return }
        let fileURL = audioRecorder.stopRecording()
        self.audioRecorder = nil

        guard let fileURL = fileURL else {
            status = .idle
            statusMessage = "Ready"
            return
        }

        status = .transcribing
        statusMessage = "⏳ Transcribing..."

        let text = await transcriber.transcribe(fileURL: fileURL)

        if let text = text, !text.isEmpty {
            textInserter.insertText(text)
            let preview = text.count > 60 ? String(text.prefix(60)) + "..." : text
            statusMessage = "✅ \(preview)"
        } else {
            statusMessage = "No speech detected"
        }

        try? FileManager.default.removeItem(at: fileURL)
        status = .idle
    }

    func cancelRecording() {
        if status == .recording {
            if let url = audioRecorder?.stopRecording() {
                try? FileManager.default.removeItem(at: url)
            }
            audioRecorder = nil
        }
        status = .idle
        statusMessage = "Cancelled"
    }
}
