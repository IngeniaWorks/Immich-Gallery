import SwiftUI

extension MemoriesView {
    
    var showCountdownForIdle: Bool {
        return idleTimerTick >= 20
    }
    
    func startIdleTimer() {
        stopIdleTimer()
        resetIdleTimer()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !showingFullScreen && selectedExploreItem == nil {
                idleTimerTick += 1
            }
        }
    }
    
    func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }
    
    func resetIdleTimer() {
        idleTimerTick = 0
        countdownTargetDate = nil
    }
}
