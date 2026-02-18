import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.headline)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Recording Hotkey")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isRecording ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isRecording ? Color.red : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        if isRecording {
                            Text("Press keys...")
                                .foregroundColor(.red)
                        } else {
                            Text(appState.shortcut.description)
                                .fontWeight(.medium)
                        }
                    }
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                    .background(ShortcutRecorder(isRecording: $isRecording, shortcut: $appState.shortcut))
                    .onTapGesture {
                        isRecording = true
                    }
                    
                    if isRecording {
                        Button("Cancel") {
                            isRecording = false
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Record") {
                            isRecording = true
                        }
                    }
                }
                
                Text(appState.shortcut.keyCode == nil ? "Mode: Hold to Record" : "Mode: Toggle (Press to Start/Stop)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}

// Hidden view to capture key events purely for recording
struct ShortcutRecorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var shortcut: Shortcut
    
    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.isRecording = isRecording
        if isRecording {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: RecorderViewDelegate {
        var parent: ShortcutRecorder
        
        init(_ parent: ShortcutRecorder) {
            self.parent = parent
        }
        
        func didRecord(_ shortcut: Shortcut) {
            parent.shortcut = shortcut
            parent.isRecording = false
        }
    }
}

protocol RecorderViewDelegate: AnyObject {
    func didRecord(_ shortcut: Shortcut)
}

class RecorderView: NSView {
    weak var delegate: RecorderViewDelegate?
    var isRecording = false
    private var maxFlagsSeen: NSEvent.ModifierFlags = []
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else { return super.keyDown(with: event) }
        
        // Valid key pressed, commit immediately
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let code = event.keyCode
        
        // Ignore "Enter" if it's being used to start recording? No, we used mouse click.
        
        let shortcut = Shortcut(keyCode: code, modifiers: UInt64(flags.rawValue))
        delegate?.didRecord(shortcut)
        maxFlagsSeen = []
    }
    
    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { return super.flagsChanged(with: event) }
        
        let currentFlags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        
        if currentFlags.rawValue > maxFlagsSeen.rawValue {
            maxFlagsSeen = currentFlags
        }
        
        // If all keys released and we saw some flags, commit them
        if currentFlags.isEmpty && !maxFlagsSeen.isEmpty {
            let shortcut = Shortcut(keyCode: nil, modifiers: UInt64(maxFlagsSeen.rawValue))
            delegate?.didRecord(shortcut)
            maxFlagsSeen = []
        }
    }
}
