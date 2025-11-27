// WaveformView.swift
import SwiftUI
import AVFoundation

struct WaveformView: View {
    let url: URL
    let currentTime: TimeInterval
    let duration: TimeInterval
    
    @State private var samples: [Float] = []
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?
    private let targetSampleCount = 100
    
    var body: some View {
        GeometryReader { geometry in
            if samples.isEmpty {
                PlaceholderWaveform()
                    .onAppear {
                        loadSamplesIfNeeded()
                    }
                    .onDisappear {
                        cancelLoading()
                    }
            } else {
                waveformPath(in: geometry.size)
                    .fill(Color.accentColor.opacity(0.8))
                    .animation(.easeInOut(duration: 0.05), value: currentTime)
            }
        }
    }
    
    private func waveformPath(in size: CGSize) -> Path {
        var path = Path()
        let width = size.width
        let height = size.height
        let middleY = height / 2
        let barCount = samples.count
        let stepX = width / CGFloat(barCount)
        let barWidth = max(1, stepX - 1)

        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * stepX
            let progress = duration > 0 ? currentTime / duration : 0
            let currentBarIndex = Int(progress * Double(barCount))
            let baseHeight = max(2, CGFloat(sample) * height)
            let barHeight: CGFloat

            if index < currentBarIndex {
                barHeight = baseHeight * 0.6
            } else if index == currentBarIndex {
                barHeight = baseHeight * 1.3
            } else {
                barHeight = baseHeight
            }

            let y = middleY - barHeight / 2
            let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: barWidth/2, height: barWidth/2))
        }

        return path
    }

    private func loadSamplesIfNeeded() {
        guard !isLoading else { return }
        isLoading = true

        loadTask = Task(priority: .userInitiated) {
            if let cached = await WaveformSampleCache.shared.samples(for: url) {
                await MainActor.run {
                    samples = cached
                    isLoading = false
                }
                return
            }

            do {
                let result = try await WaveformLoader.loadSamples(url: url, targetSampleCount: targetSampleCount)
                await WaveformSampleCache.shared.insert(result, for: url)
                await MainActor.run {
                    samples = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    private func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
    }
}

private struct PlaceholderWaveform: View {
    var body: some View {
        GeometryReader { geometry in
            let barCount = 60
            let width = geometry.size.width
            let height = geometry.size.height
            let stepX = width / CGFloat(barCount)
            let barWidth = max(1, stepX - 2)

            Path { path in
                for index in 0..<barCount {
                    let normalized = sin(Double(index) / Double(barCount) * .pi)
                    let barHeight = CGFloat(0.2 + 0.8 * normalized) * height
                    let x = CGFloat(index) * stepX
                    let y = (height - barHeight) / 2
                    let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                    path.addRoundedRect(in: rect, cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2))
                }
            }
            .fill(Color.gray.opacity(0.2))
        }
    }
}

private actor WaveformSampleCache {
    static let shared = WaveformSampleCache()
    private var storage: [URL: [Float]] = [:]

    func samples(for url: URL) -> [Float]? {
        storage[url]
    }

    func insert(_ samples: [Float], for url: URL) {
        storage[url] = samples
    }
}

private enum WaveformLoader {
    static func loadSamples(url: URL, targetSampleCount: Int) async throws -> [Float] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let file = try AVAudioFile(forReading: url)
                    let format = file.processingFormat
                    let frameCount = UInt32(file.length)
                    guard frameCount > 0 else {
                        continuation.resume(returning: [])
                        return
                    }
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                        continuation.resume(returning: [])
                        return
                    }
                    try file.read(into: buffer)
                    guard let channelData = buffer.floatChannelData?.pointee else {
                        continuation.resume(returning: [])
                        return
                    }
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
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
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
