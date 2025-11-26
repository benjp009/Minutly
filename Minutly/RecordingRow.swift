//
//  RecordingRow.swift
//  Minutly
//
//  Created by Benjamin Patin on 26/11/2025.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct RecordingRow: View {
    let url: URL
    let onDelete: () -> Void
    let onRename: (String) -> Void
    
    @State private var isPlaying = false
    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var audioPlayer: AVAudioPlayer?
    @State private var timer: Timer?
    @State private var currentTime: TimeInterval = 0
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Name or Edit Field
                if isEditingName {
                    TextField("Recording Name", text: $editedName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            finishEditing()
                        }
                    
                    Button(action: finishEditing) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(cleanName(from: url))
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    
                    Button(action: {
                        editedName = cleanName(from: url)
                        isEditingName = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Play/Pause Button
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                
                // Download Button
                Button(action: downloadRecording) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                
                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            
            if isPlaying {
                WaveformView(
                    url: url,
                    currentTime: currentTime,
                    duration: audioPlayer?.duration ?? 0
                )
                .frame(height: 40)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onDisappear {
            stopPlayback()
        }
    }
    
    private func finishEditing() {
        if !editedName.isEmpty {
            onRename(editedName)
        }
        isEditingName = false
    }
    
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = PlayerDelegate(onFinish: {
                stopPlayback()
            })
            audioPlayer?.play()
            isPlaying = true
            currentTime = 0
            
            // Start timer to update current time
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [self] _ in
                if let player = audioPlayer {
                    currentTime = player.currentTime
                }
            }
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    private func stopPlayback() {
        timer?.invalidate()
        timer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
    }
    
    private func cleanName(from url: URL) -> String {
        return url.deletingPathExtension().lastPathComponent
    }
    
    private func downloadRecording() {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = url.lastPathComponent
        savePanel.allowedContentTypes = [.wav]
        
        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    // Copy file to selected location
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                } catch {
                    print("Failed to save file: \(error)")
                }
            }
        }
    }
}

// Helper delegate to handle playback finish
class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
