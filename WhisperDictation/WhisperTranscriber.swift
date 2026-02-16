import Foundation

class WhisperTranscriber {
    private var whisperContext: WhisperContext?

    func loadModel(path: String) async {
        do {
            whisperContext = try WhisperContext.createContext(path: path)
            print("✅ Model loaded: \(path)")
        } catch {
            print("❌ Failed to load model: \(error)")
        }
    }

    var isModelLoaded: Bool {
        whisperContext != nil
    }

    func transcribe(fileURL: URL) async -> String? {
        guard let context = whisperContext else {
            print("No model loaded")
            return nil
        }

        do {
            let samples = try decodeWaveFile(fileURL)
            await context.fullTranscribe(samples: samples)
            let text = await context.getTranscription()
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Transcription error: \(error)")
            return nil
        }
    }
}
