import Cocoa

class TextInserter {
    func insertText(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Save current clipboard contents
        let previousContents = pasteboard.string(forType: .string)

        // Set transcribed text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("📋 Text set to clipboard: \(text.prefix(50))...")

        // Small delay to ensure pasteboard is ready, then simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()

            // Restore original clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let previousContents = previousContents {
                    pasteboard.clearContents()
                    pasteboard.setString(previousContents, forType: .string)
                    print("📋 Clipboard restored")
                }
            }
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code 9 = 'v'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        if keyDown != nil {
            print("✅ Simulated Cmd+V paste")
        } else {
            print("⚠️ Failed to create CGEvent — check Accessibility permissions")
        }
    }
}
