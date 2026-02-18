import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private var floatingWindowController: FloatingIndicatorWindowController?
    private var stateObservation: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 App launched — setting up hotkey manager")
        let state = AppState.shared
        
        // Initialize Floating Window
        floatingWindowController = FloatingIndicatorWindowController(rootView: FloatingIndicatorView())

        hotkeyManager = HotkeyManager(
            onRecordStart: {
                Task { @MainActor in state.startRecording() }
            },
            onRecordStop: {
                Task { @MainActor in await state.stopRecordingAndTranscribe() }
            },
            onCancel: {
                Task { @MainActor in state.cancelRecording() }
            }
        )

        // Load model
        state.loadModelFromBundle()
        
        setupStateObservation()
    }
}

extension AppDelegate {
    func setupStateObservation() {
        let state = AppState.shared
        // Keep a reference to the cancellable
        self.stateObservation = state.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self = self, let window = self.floatingWindowController?.window else { return }
                
                if status == .recording || status == .transcribing {
                    if !window.isVisible {
                        window.orderFront(nil)
                    }
                } else {
                    if window.isVisible {
                        window.orderOut(nil)
                    }
                }
            }
    }
}

@main
struct WhisperDictationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "waveform.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    Text("Whisper Dictation")
                        .font(.headline)
                }

                Divider()

                HStack(spacing: 8) {
                    Circle()
                        .fill(appState.statusColor)
                        .frame(width: 8, height: 8)
                    Text(appState.statusLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text(appState.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                Toggle("Punctuation", isOn: $appState.usePunctuation)
                    .toggleStyle(.switch)
                    .font(.subheadline)
                
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Label("Hold **Left Ctrl + Left Option** to record", systemImage: "keyboard")
                        .font(.caption)
                    Label("Release to transcribe", systemImage: "text.bubble")
                        .font(.caption)
                    Label("Press **ESC** to cancel", systemImage: "escape")
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                Divider()

                Button("Quit Whisper Dictation") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding(12)
            .frame(width: 280)
        } label: {
            Image(systemName: appState.statusIcon)
        }
        .menuBarExtraStyle(.window)
    }
}
