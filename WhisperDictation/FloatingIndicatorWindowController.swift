import Cocoa
import SwiftUI

class FloatingIndicatorWindowController: NSWindowController {
    convenience init(rootView: some View) {
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isMovableByWindowBackground = true // Allow user to move it
        
        // Center horizontally, lower third vertically
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - 100
            let y = screenRect.minY + 150 // Slightly above dock/bottom
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.contentViewController = hostingController
        self.init(window: window)
    }
}
