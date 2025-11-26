// AudioPlayerView.swift
import SwiftUI
import AVFoundation

struct AudioPlayerView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0.0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 16) {
            Text(url.lastPathComponent)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            // Simple waveform placeholder
            WaveformView(
                url: url,
                currentTime: player?.currentTime ?? 0,
                duration: player?.duration ?? 0
            )
            .frame(height: 80)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            // Progress bar
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 4)
                .padding(.horizontal)
            HStack(spacing: 40) {
                Button(isPlaying ? "Pause" : "Play") {
                    togglePlay()
                }
                .font(.title2)
                .buttonStyle(.borderedProminent)
                
                Button("Done") {
                    stopAndDismiss()
                }
                .font(.title2)
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .onAppear {
            preparePlayer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func preparePlayer() {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
        } catch {
            // handle error silently
        }
    }
    
    private func togglePlay() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            timer?.invalidate()
        } else {
            player.play()
            startTimer()
        }
        isPlaying.toggle()
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if let player = player {
                progress = player.currentTime / player.duration
                if !player.isPlaying {
                    timer?.invalidate()
                    isPlaying = false
                }
            }
        }
    }
    
    private func stopAndDismiss() {
        player?.stop()
        timer?.invalidate()
        dismiss()
    }
}

struct AudioPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        // Use a dummy URL; replace with a real file when testing
        AudioPlayerView(url: URL(fileURLWithPath: "/tmp/dummy.wav"))
    }
}
