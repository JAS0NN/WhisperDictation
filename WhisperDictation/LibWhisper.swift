import Foundation
import AppKit
import whisper

enum WhisperError: Error {
    case couldNotInitializeContext
}

actor WhisperContext {
    private var context: OpaquePointer

    init(context: OpaquePointer) {
        self.context = context
    }

    deinit {
        whisper_free(context)
    }

    func fullTranscribe(samples: [Float], prompt: String? = nil, noContext: Bool = true) {
        let maxThreads = max(1, min(8, cpuCount() - 2))
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        
        "auto".withCString { lang in
            params.print_realtime   = true
            params.print_progress   = false
            params.print_timestamps = true
            params.print_special    = false
            params.translate        = false
            params.language         = lang
            params.n_threads        = Int32(maxThreads)
            params.offset_ms        = 0
            params.no_context       = noContext
            params.single_segment   = false
            
            let body = {
                whisper_reset_timings(self.context)
                samples.withUnsafeBufferPointer { samples in
                    if whisper_full(self.context, params, samples.baseAddress, Int32(samples.count)) != 0 {
                        print("Failed to run the model")
                    } else {
                        whisper_print_timings(self.context)
                    }
                }
            }
            
            if let prompt = prompt {
                prompt.withCString { p in
                    params.initial_prompt = p
                    body()
                }
            } else {
                body()
            }
        }
    }

    func getTranscription() -> String {
        var transcription = ""
        for i in 0..<whisper_full_n_segments(context) {
            transcription += String(cString: whisper_full_get_segment_text(context, i))
        }
        return transcription
    }

    static func createContext(path: String) throws -> WhisperContext {
        var params = whisper_context_default_params()
        #if canImport(CoreML)
        params.use_gpu = true
        #endif
        params.flash_attn = true
        let context = whisper_init_from_file_with_params(path, params)
        if let context {
            return WhisperContext(context: context)
        } else {
            print("Couldn't load model at \(path)")
            throw WhisperError.couldNotInitializeContext
        }
    }
}

fileprivate func cpuCount() -> Int {
    ProcessInfo.processInfo.processorCount
}
