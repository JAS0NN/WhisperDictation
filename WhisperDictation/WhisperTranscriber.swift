import Foundation

class WhisperTranscriber {
    private var whisperContext: WhisperContext?

    func loadModel(path: String) async {
        print("⏳ Loading model from: \(path)")
        
        do {
            // Offload the heavy C++ loading to a background thread
            let context = try await Task.detached(priority: .userInitiated) {
                return try WhisperContext.createContext(path: path)
            }.value
            
            whisperContext = context
            print("✅ Model loaded successfully")
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
            // Post-processing VAD: Remove silence from recorded audio
            let filteredSamples = removeSilence(from: samples)
            
            print("Processing audio: \(samples.count) samples -> \(filteredSamples.count) samples (VAD)")
            
            await context.fullTranscribe(samples: filteredSamples)
            let text = await context.getTranscription()
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Transcription error: \(error)")
            return nil
        }
    }
    
    /// Basic energy-based VAD to remove silent segments
    private func removeSilence(from samples: [Float], sampleRate: Int = 16000) -> [Float] {
        let windowDuration = 0.03 // 30ms window
        let windowSize = Int(Double(sampleRate) * windowDuration)
        let silenceThreshold: Float = 0.05 // Adjusted amplitude threshold (~ -26dB) - increasing sensitivity
        let paddingDuration = 0.3 // 300ms padding
        let paddingSamples = Int(Double(sampleRate) * paddingDuration)
        
        var keptSamples = [Float]()
        var speechRegions = [(start: Int, end: Int)]()
        var currentRegion: (start: Int, end: Int)?
        
        // 1. Detect speech regions
        for i in stride(from: 0, to: samples.count, by: windowSize) {
            let endIndex = min(i + windowSize, samples.count)
            let window = samples[i..<endIndex]
            
            // Calculate max amplitude in window
            let maxAmp = window.map { abs($0) }.max() ?? 0
            
            if maxAmp > silenceThreshold {
                if currentRegion == nil {
                    currentRegion = (start: i, end: endIndex)
                } else {
                    currentRegion?.end = endIndex
                }
            } else {
                // End of speech region if strictly silent, but we'll merge close regions later
                if let region = currentRegion {
                    speechRegions.append(region)
                    currentRegion = nil
                }
            }
        }
        
        if let region = currentRegion {
            speechRegions.append(region)
        }
        
        // 2. Merge close regions and add padding
        guard !speechRegions.isEmpty else { return samples } // Return original if everything is silence (let model handle it)
        
        var mergedRegions = [(start: Int, end: Int)]()
        
        for region in speechRegions {
            // Apply padding
            let paddedStart = max(0, region.start - paddingSamples)
            let paddedEnd = min(samples.count, region.end + paddingSamples)
            
            if let last = mergedRegions.last {
                if paddedStart <= last.end {
                    // Merge overlap
                    mergedRegions[mergedRegions.count - 1].end = max(last.end, paddedEnd)
                } else {
                    mergedRegions.append((start: paddedStart, end: paddedEnd))
                }
            } else {
                mergedRegions.append((start: paddedStart, end: paddedEnd))
            }
        }
        
        // 3. Construct new sample array
        for region in mergedRegions {
            keptSamples.append(contentsOf: samples[region.start..<region.end])
        }
        
        // If we filtered out too much (e.g. less than 0.5s remaining), might be safer to fallback to original
        if keptSamples.count < sampleRate / 2 {
             print("⚠️ VAD filtered too aggressively, falling back to original audio")
             return samples
        }
        
        return keptSamples
    }
}
