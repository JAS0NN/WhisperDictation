import Cocoa
import Combine

@MainActor
class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    
    // Tracking state
    private var currentModifiers: NSEvent.ModifierFlags = []
    
    // AppState reference
    private var appState = AppState.shared

    var onRecordStart: (() -> Void)?
    var onRecordStop: (() -> Void)?
    var onCancel: (() -> Void)?

    init(onRecordStart: @escaping () -> Void,
         onRecordStop: @escaping () -> Void,
         onCancel: @escaping () -> Void) {
        self.onRecordStart = onRecordStart
        self.onRecordStop = onRecordStop
        self.onCancel = onCancel
        setupMonitors()
    }

    deinit {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }

    private func setupMonitors() {
        // Monitor events in OTHER apps
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
        }

        // Monitor events in OUR app
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
        
        print("✅ Event monitors setup")
    }

    private func handleEvent(_ event: NSEvent) {
        let shortcut = appState.shortcut
        
        if event.type == .flagsChanged {
            // Update current modifiers
            // We need to filter out non-modifier flags (like device dependent ones)
            // But for simple matching, let's just use the event's raw flags
            // However, distinguishing Left/Right is hard with just flags.
            // standard .control includes both.
            // For now, let's trust the shortcut.modifiers which comes from a recorded event.
            
            // Wait, to support "Hold", we need to see if the current state MATCHES the target.
            // The shortcut saved likely has strict flags.
            
            // Check if matches target shortcut (assuming modifiers only or mixed)
            let currentFlags = event.modifierFlags.intersection([.command, .control, .option, .shift])
            let targetFlags = NSEvent.ModifierFlags(rawValue: UInt(shortcut.modifiers)).intersection([.command, .control, .option, .shift])
            
            // Logic for "Hold Mode" (Modifiers only or Key + Modifiers)
            // If the shortcut HAS a keyCode, flagsChanged alone isn't enough to START, unless we treat it as hold.
            // But typically key+mod is "Toggle". Modifiers-only is "Hold".
            
            let isTargetModifiers = currentFlags == targetFlags
            let isRecording = appState.status == .recording
            
            // Case 1: Modifiers Only Shortcut (e.g. Ctrl+Opt)
            if shortcut.keyCode == nil {
                if isTargetModifiers && !isRecording {
                    onRecordStart?()
                } else if !isTargetModifiers && isRecording {
                    // Recording, but modifiers released/changed -> Stop
                    onRecordStop?()
                }
            }
            
        } else if event.type == .keyDown {
            // Check for ESC to cancel
            if event.keyCode == 53 && appState.status == .recording {
                onCancel?()
                return
            }
            
            // Case 2: Key Code Shortcut (e.g. F1, or Cmd+Space)
            // Usually acts as Toggle
            if let targetCode = shortcut.keyCode {
                if event.keyCode == targetCode {
                    // Check modifiers if any
                    let currentFlags = event.modifierFlags.intersection([.command, .control, .option, .shift])
                    let targetFlags = NSEvent.ModifierFlags(rawValue: UInt(shortcut.modifiers)).intersection([.command, .control, .option, .shift])
                    
                    if currentFlags == targetFlags {
                        if appState.status == .recording {
                            onRecordStop?()
                        } else {
                            onRecordStart?()
                        }
                    }
                }
            }
        }
    }
}
