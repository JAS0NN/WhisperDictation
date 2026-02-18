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
    
    private init() {
        // Load shortcut or default to Left Ctrl + Left Option
        if let data = UserDefaults.standard.data(forKey: "recordShortcut"),
           let loaded = try? JSONDecoder().decode(Shortcut.self, from: data) {
            self.shortcut = loaded
        } else {
            // Default: Left Control (0x40001) + Left Option (0x80020)
            // Note: raw values depend on NSEvent.ModifierFlags
            // .control = 1<<18, .option = 1<<19
            let mods = NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue
            self.shortcut = Shortcut(keyCode: nil, modifiers: UInt64(mods))
        }
    }

    @Published var status: DictationStatus = .idle
    @Published var statusMessage: String = "Initializing..."
    @Published var usePunctuation: Bool = true
    @Published var audioLevel: Float = 0.0
    
    @Published var shortcut: Shortcut {
        didSet {
            if let data = try? JSONEncoder().encode(shortcut) {
                UserDefaults.standard.set(data, forKey: "recordShortcut")
            }
        }
    }

    private var audioRecorder: AudioRecorder?
    private let transcriber = WhisperTranscriber()
    private let textInserter = TextInserter()

    var statusIcon: String {
        switch status {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform.badge.magnifyingglass"
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
            
            // Link VAD silence detection
            audioRecorder?.onSilenceDetected = { [weak self] in
                Task { @MainActor in
                    await self?.stopRecordingAndTranscribe()
                }
            }
            
            // Link Audio Metering for UI
            audioRecorder?.onAudioLevelUpdate = { [weak self] level in
                Task { @MainActor in
                    self?.audioLevel = level
                }
            }
            
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

        // Punctuation Control
        // Enabled: Prompt with mixed English/Chinese punctuation.
        // Disabled: Prompt with lowercase/no punctuation in both languages.
        let prompt = usePunctuation 
            ? "Hello, 歡迎來到我的演講。我會說得清晰，並使用正確的標點符號。" 
            : "hello ni hao how are you i hope you are doing well today no punctuation here"
        let noContext = !usePunctuation

        let text = await transcriber.transcribe(fileURL: fileURL, prompt: prompt, noContext: noContext)

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
