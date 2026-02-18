import SwiftUI

struct FloatingIndicatorView: View {
    @ObservedObject var appState = AppState.shared
    
    var body: some View {
        HStack(spacing: 4) {
            if appState.status == .recording {
                // Waveform animation driven by audioLevel
                ForEach(0..<5) { index in
                    AudioBar(level: appState.audioLevel, index: index)
                }
            } else if appState.status == .transcribing {
                // Loading spinner
                ProgressView()
                    .controlSize(.small)
                    .colorScheme(.dark)
            } else {
                // Should be hidden, but just in case
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Material.ultraThinMaterial) // Glass effect
        .background(Color.black.opacity(0.6)) // Dark tint
        .clipShape(Capsule())
        .shadow(radius: 4)
        .animation(.easeInOut(duration: 0.2), value: appState.status)
    }
}

struct AudioBar: View {
    var level: Float
    var index: Int
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(width: 4, height: heightForLevel(level, at: index))
            // Basic animation smoothing
            .animation(.linear(duration: 0.05), value: level)
    }
    
    private func heightForLevel(_ level: Float, at index: Int) -> CGFloat {
        // Create a symmetric wave pattern based on index (0,1,2,1,0)
        // and modulate height by audio level
        let baseHeight: CGFloat = 4.0
        let maxHeight: CGFloat = 24.0
        
        // Add some random/per-bar variation or fixed pattern
        let scale: CGFloat
        if index == 2 { scale = 1.0 }
        else if index == 1 || index == 3 { scale = 0.7 }
        else { scale = 0.4 }
        
        // Dynamic height: base + (max - base) * level * scale
        // Ensure minimum visibility
        return baseHeight + (maxHeight - baseHeight) * CGFloat(max(0.1, level)) * scale
    }
}
