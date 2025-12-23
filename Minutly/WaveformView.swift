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
    /// Chunk size for waveform generation (10 seconds at 48kHz = 480,000 frames)
    /// This keeps memory usage constant at ~46 MB per chunk regardless of total file size
    private static let chunkFrames: AVAudioFrameCount = 480_000

    static func loadSamples(url: URL, targetSampleCount: Int) async throws -> [Float] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Check if file is encrypted (.enc or .encrypted extension)
                    let fileURL: URL
                    var tempFileToCleanup: URL?

                    if url.pathExtension == "enc" || url.pathExtension == "encrypted" {
                        // Decrypt the file temporarily
                        let encryptionService = EncryptionService.shared
                        let decryptedData = try encryptionService.decryptFileTemporarily(at: url)

                        // Write to temporary file
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension("wav")
                        try decryptedData.write(to: tempURL)

                        fileURL = tempURL
                        tempFileToCleanup = tempURL
                    } else {
                        fileURL = url
                    }

                    // Cleanup temp file on any exit path
                    defer {
                        if let tempFile = tempFileToCleanup {
                            try? FileManager.default.removeItem(at: tempFile)
                        }
                    }

                    // Load waveform using chunked processing
                    let samples = try loadSamplesChunked(fileURL: fileURL, targetSampleCount: targetSampleCount)
                    continuation.resume(returning: samples)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Chunked waveform loading for memory efficiency
    /// Memory footprint: ~46 MB constant vs 1.38 GB for 1-hour recording with old approach
    private static func loadSamplesChunked(fileURL: URL, targetSampleCount: Int) throws -> [Float] {
        // Open audio file
        let file = try AVAudioFile(forReading: fileURL)
        let format = file.processingFormat
        let totalFrameCount = AVAudioFrameCount(file.length)

        guard totalFrameCount > 0 else {
            return []
        }

        // Calculate how many frames each output sample should represent
        let framesPerOutputSample = max(1, Int(totalFrameCount) / targetSampleCount)

        // Create reusable buffer for chunked reading
        let chunkSize = min(chunkFrames, totalFrameCount)
        guard let chunkBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize) else {
            return []
        }

        var result: [Float] = []
        result.reserveCapacity(targetSampleCount)

        var processedFrames: AVAudioFrameCount = 0
        var currentBucketSum: Float = 0
        var currentBucketFrameCount: Int = 0
        var framesInCurrentOutputSample: Int = 0

        // Process file in chunks
        while processedFrames < totalFrameCount {
            let framesToRead = min(chunkSize, totalFrameCount - processedFrames)

            // Read chunk
            chunkBuffer.frameLength = 0
            try file.read(into: chunkBuffer, frameCount: framesToRead)

            guard let channelData = chunkBuffer.floatChannelData?.pointee else {
                continue
            }

            let framesRead = Int(chunkBuffer.frameLength)

            // Process frames in this chunk
            for frameIndex in 0..<framesRead {
                let sample = abs(channelData[frameIndex])
                currentBucketSum += sample
                currentBucketFrameCount += 1
                framesInCurrentOutputSample += 1

                // Check if we've accumulated enough frames for one output sample
                if framesInCurrentOutputSample >= framesPerOutputSample {
                    let avg = currentBucketSum / Float(currentBucketFrameCount)
                    result.append(avg)

                    // Reset for next output sample
                    currentBucketSum = 0
                    currentBucketFrameCount = 0
                    framesInCurrentOutputSample = 0
                }
            }

            processedFrames += AVAudioFrameCount(framesRead)
        }

        // Add any remaining partial bucket
        if currentBucketFrameCount > 0 {
            let avg = currentBucketSum / Float(currentBucketFrameCount)
            result.append(avg)
        }

        return result
    }
}

struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a dummy URL for preview; replace with a real file when testing
        WaveformView(url: URL(fileURLWithPath: "/tmp/dummy.wav"), currentTime: 0, duration: 10)
            .frame(height: 80)
    }
}
