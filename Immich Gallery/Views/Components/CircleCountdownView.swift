//
//  CircleCountdownView.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2026-01-27.
//

import SwiftUI

struct CircleCountdownView: View {
    let totalTime: TimeInterval
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var timeRemaining: TimeInterval
    @State private var timer: Timer?
    @State private var isActive = false
    
    init(totalTime: TimeInterval, onComplete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.totalTime = totalTime
        self.onComplete = onComplete
        self.onCancel = onCancel
        _timeRemaining = State(initialValue: totalTime)
    }
    
    var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(lineWidth: 4)
                .opacity(0.3)
                .foregroundColor(.gray)
            
            // Progress Circle
            Circle()
                .trim(from: 0.0, to: CGFloat(timeRemaining / totalTime))
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .foregroundColor(.white)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear(duration: 1.0), value: timeRemaining)
            
            // Number Text
            Text("\(Int(ceil(timeRemaining)))")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 50, height: 50)
        .padding(10)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        guard !isActive else { return }
        isActive = true
        timeRemaining = totalTime
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                withAnimation {
                    timeRemaining -= 1
                }
            } else {
                stopTimer()
                onComplete()
            }
        }
    }
    
    private func stopTimer() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    ZStack {
        Color.black
        CircleCountdownView(totalTime: 5, onComplete: {}, onCancel: {})
    }
}
