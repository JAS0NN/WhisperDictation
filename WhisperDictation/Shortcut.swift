import Foundation
import Cocoa

struct Shortcut: Codable, Equatable {
    var keyCode: UInt16?     // Physical key (e.g. 53 for ESC, 49 for Space) -> Optional because maybe user only wants modifiers? 
                             // Actually, purely modifiers is hard to distinguish from just using the computer. 
                             // But let's allow "Double Tap Ctrl" later? No, stick to "Key + Modifiers" or "Modifiers Only".
    var modifiers: UInt64    // NSEvent.ModifierFlags.rawVal value
    
    // Helper property to get readable string
    var description: String {
        var str = ""
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        
        if flags.contains(.control) { str += "⌃" }
        if flags.contains(.option) { str += "⌥" }
        if flags.contains(.shift) { str += "⇧" }
        if flags.contains(.command) { str += "⌘" }
        // Fn key is tricky, often not reported as a flag in the same way, but let's stick to standard 4
        
        if let code = keyCode {
            str += keyString(for: code)
        }
        
        return str.isEmpty ? "None" : str
    }
    
    private func keyString(for code: UInt16) -> String {
        // Simple mapping for common keys, otherwise use library or Unicode
        switch code {
        case 49: return "Space"
        case 36: return "Enter"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        // F1-F12
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            // Fallback: This is rough, mapping virtual keycard to string is complex in macOS without Carbon
            // For now, simpler approach: Just use empty if unknown or try basic ASCII
            return String(format: "[%d]", code)
        }
    }
}
