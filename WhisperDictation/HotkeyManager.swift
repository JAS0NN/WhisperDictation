import Cocoa

class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private var leftCtrlPressed = false
    private var leftOptionPressed = false
    private var isRecording = false

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

        if globalMonitor != nil {
            print("✅ Global event monitor created successfully")
        } else {
            print("⚠️ Failed to create global event monitor. Check Accessibility permissions.")
        }
    }

    private func handleEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            let keyCode = event.keyCode

            if keyCode == 59 { // Left Control
                leftCtrlPressed = event.modifierFlags.contains(.control)
            } else if keyCode == 58 { // Left Option
                leftOptionPressed = event.modifierFlags.contains(.option)
            }

            if leftCtrlPressed && leftOptionPressed && !isRecording {
                isRecording = true
                onRecordStart?()
            } else if isRecording && (!leftCtrlPressed || !leftOptionPressed) {
                isRecording = false
                onRecordStop?()
            }
        } else if event.type == .keyDown {
            if event.keyCode == 53 && isRecording { // ESC
                isRecording = false
                leftCtrlPressed = false
                leftOptionPressed = false
                onCancel?()
            }
        }
    }
}
