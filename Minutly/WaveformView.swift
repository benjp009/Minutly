// WaveformView.swift
import SwiftUI
import AVFoundation

struct WaveformView: View {
    let url: URL
    let currentTime: TimeInterval
    let duration: TimeInterval
    
    @State private var samples: [Float] = []
    private let targetSampleCount = 100
    
    var body: some View {
        GeometryReader { geometry in
            if samples.isEmpty {
                Color.clear.onAppear {
                    loadSamples()
                }
            } else {
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let middleY = height / 2
                    let barCount = samples.count
                    let stepX = width / CGFloat(barCount)
                    let barWidth = max(1, stepX - 1) // Leave a small gap
                    
                    for (index, sample) in samples.enumerated() {
                        let x = CGFloat(index) * stepX
                        
                        // Calculate progress through the waveform
                        let progress = duration > 0 ? currentTime / duration : 0
                        let currentBarIndex = Int(progress * Double(barCount))
                        
                        // Determine bar height based on position
                        let baseHeight = max(2, CGFloat(sample) * height)
                        let barHeight: CGFloat
                        
                        // Make current position bar larger, and fade bars that have been played
                        if index < currentBarIndex {
                            // Played bars - slightly dimmed
                            barHeight = baseHeight * 0.6
                        } else if index == currentBarIndex {
                            // Current bar - emphasized
                            barHeight = baseHeight * 1.3
                        } else {
                            // Upcoming bars - normal
                            barHeight = baseHeight
                        }
                        
                        let y = middleY - barHeight / 2
                        
                        let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                        path.addRoundedRect(in: rect, cornerSize: CGSize(width: barWidth/2, height: barWidth/2))
                    }
                }
                .fill(Color.accentColor.opacity(0.8))
                .animation(.easeInOut(duration: 0.05), value: currentTime)
            }
        }
    }
    
    private func loadSamples() {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = UInt32(file.length)
            guard frameCount > 0 else { return }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            try file.read(into: buffer)
            guard let channelData = buffer.floatChannelData?.pointee else { return }
            let totalFrames = Int(buffer.frameLength)
            let samplesPerBucket = max(1, totalFrames / targetSampleCount)
            var result: [Float] = []
            var i = 0
            while i < totalFrames {
                let end = min(i + samplesPerBucket, totalFrames)
                var sum: Float = 0
                for j in i..<end {
                    sum += abs(channelData[j])
                }
                let avg = sum / Float(end - i)
                result.append(avg)
                i = end
            }
            self.samples = result
        } catch {
            // Silently ignore errors
        }
    }
}

struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a dummy URL for preview; replace with a real file when testing
        WaveformView(url: URL(fileURLWithPath: "/tmp/dummy.wav"), currentTime: 0, duration: 10)
            .frame(height: 80)
    }
}
