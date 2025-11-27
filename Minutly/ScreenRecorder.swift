//
//  ScreenRecorder.swift
//  Minutly
//
//  Created by Benjamin Patin on 25/11/2025.
//

import Foundation
import ScreenCaptureKit
@preconcurrency import AVFoundation
import Combine
import AppKit


@MainActor
class ScreenRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var lastRecordingPath: String?
    @Published var errorMessage: String?

    @Published var recordings: [URL] = []

    // Current meeting title (if recording from calendar event)
    var currentMeetingTitle: String?

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var tempURL: URL?
    // Microphone recorder
    private var micRecorder: AVAudioRecorder?
    private var micTempURL: URL?

    // Transcription service
    let transcriptionService: TranscriptionService

    // Pre-buffering
    @Published var isPreBuffering = false
    private var preBufferData: [CMSampleBuffer] = []
    private let preBufferDuration: TimeInterval = 30.0 // 30 seconds
    private var preBufferQueue = DispatchQueue(label: "com.minutly.prebuffer")

    override init() {
        self.transcriptionService = TranscriptionService()
        super.init()
    }

    // MARK: - Pre-buffering

    func startPreBuffering(meetingTitle: String? = nil) async {
        print("🔄 Starting pre-buffering (30 seconds)...")
        currentMeetingTitle = meetingTitle
        isPreBuffering = true
        preBufferData.removeAll()

        do {
            // Get available content (displays)
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let display = content.displays.first else {
                errorMessage = "No display found"
                return
            }

            // Create content filter for the main display
            let filter = SCContentFilter(display: display, excludingWindows: [])

            // Configure stream - minimal video settings as we only want audio
            let config = SCStreamConfiguration()
            config.width = 100
            config.height = 100
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            config.capturesAudio = true
            config.sampleRate = 48000
            config.channelCount = 2

            // Create and start stream
            stream = SCStream(filter: filter, configuration: config, delegate: nil)

            // Add stream output - ONLY audio
            try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())

            try await stream?.startCapture()

            print("✅ Pre-buffering started")

        } catch {
            errorMessage = "Failed to start pre-buffering: \(error.localizedDescription)"
            isPreBuffering = false
        }
    }

    func confirmRecordingFromPreBuffer() async {
        print("✅ User confirmed recording - saving pre-buffer...")

        guard isPreBuffering else {
            // If not pre-buffering, just start normal recording
            await startRecording()
            return
        }

        isPreBuffering = false
        isRecording = true

        // Continue with normal recording setup but include pre-buffer
        await startRecordingWithPreBuffer()
    }

    func cancelPreBuffer() async {
        print("❌ User cancelled - discarding pre-buffer...")
        isPreBuffering = false
        preBufferData.removeAll()

        // Stop stream
        try? await stream?.stopCapture()
        stream = nil
    }

    private func startRecordingWithPreBuffer() async {
        do {
            // Set up temporary file output
            let tempDir = FileManager.default.temporaryDirectory
            let filename = generateFilename(meetingTitle: currentMeetingTitle)
            let sysFileName = "\(filename)_sys.wav"
            tempURL = tempDir.appendingPathComponent(sysFileName)

            guard let tempURL = tempURL else {
                errorMessage = "Failed to create temporary file path"
                return
            }

            // Remove existing file if any
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try? FileManager.default.removeItem(at: tempURL)
            }

            // Set up microphone temporary file
            let micFileName = "\(filename)_mic.wav"
            micTempURL = tempDir.appendingPathComponent(micFileName)

            // Start microphone recording
            let micSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]

            if let micURL = micTempURL {
                if FileManager.default.fileExists(atPath: micURL.path) {
                    try FileManager.default.removeItem(at: micURL)
                }

                micRecorder = try AVAudioRecorder(url: micURL, settings: micSettings)
                micRecorder?.delegate = self
                _ = micRecorder?.prepareToRecord()
                _ = micRecorder?.record()
                print("✅ Microphone recording active")
            }

            // Create asset writer for WAV
            assetWriter = try AVAssetWriter(outputURL: tempURL, fileType: .wav)

            // Audio input settings for Linear PCM (WAV)
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]

            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true

            if let audioInput = audioInput {
                if assetWriter?.canAdd(audioInput) == true {
                    assetWriter?.add(audioInput)
                }
            }

            // Start writing
            if assetWriter?.startWriting() == false {
                errorMessage = "Failed to start writing: \(assetWriter?.error?.localizedDescription ?? "Unknown error")"
                return
            }

            assetWriter?.startSession(atSourceTime: CMTime.zero)

            // Write pre-buffered data first
            print("💾 Writing \(preBufferData.count) pre-buffered samples...")
            for sampleBuffer in preBufferData {
                if let audioInput = audioInput, audioInput.isReadyForMoreMediaData {
                    audioInput.append(sampleBuffer)
                }
            }
            preBufferData.removeAll()

            print("✅ Recording started with pre-buffer")
            errorMessage = nil

        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            isRecording = false
        }
    }

    // Configure audio session for mic recording (macOS)
    private func setupAudioSession() {
        #if os(macOS)
        // On macOS, audio recording just works with AVAudioRecorder
        // No special session setup needed like on iOS
        print("✅ macOS audio environment ready")
        #else
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.recordAndPlayback, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session configured for recording")
        } catch {
            print("❌ Failed to configure audio session: \(error.localizedDescription)")
        }
        #endif
    }
    
    // Check and request microphone permission
    func checkMicrophonePermission() {
        #if os(macOS)
        // On macOS, use AVCaptureDevice to request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Microphone permission granted")
                } else {
                    print("❌ Microphone permission denied")
                    self.errorMessage = "Microphone permission is required to record audio. Please enable it in System Preferences > Security & Privacy > Microphone."
                    self.showMicPermissionAlert()
                }
            }
        }
        #else
        // iOS permission check
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Microphone permission granted")
                } else {
                    print("❌ Microphone permission denied")
                    self.errorMessage = "Microphone permission is required. Please enable it in Settings."
                }
            }
        }
        #endif
    }
    
    // Show alert for microphone permission
    private func showMicPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Permission Required"
        alert.informativeText = "Minutly needs access to your microphone to record audio. Please enable it in System Preferences > Security & Privacy > Microphone, then try again."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open System Preferences")
        
        let response = alert.runModal()
        if response == NSApplication.ModalResponse.alertSecondButtonReturn {
            // Open System Preferences
            let prefsURL = URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane")
            NSWorkspace.shared.open(prefsURL)
        }
    }
    
    // Start recording system audio
    func startRecording(meetingTitle: String? = nil) async {
        guard !isRecording else {
            print("⚠️ Already recording, start request ignored.")
            return
        }

        do {
            // Store meeting title for filename
            currentMeetingTitle = meetingTitle

            // Check microphone permission first
            print("🔐 Checking microphone permission...")
            checkMicrophonePermission()

            // Get available content (displays)
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let display = content.displays.first else {
                errorMessage = "No display found"
                return
            }

            // Create content filter for the main display
            let filter = SCContentFilter(display: display, excludingWindows: [])

            // Configure stream - minimal video settings as we only want audio
            let config = SCStreamConfiguration()
            config.width = 100
            config.height = 100
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // Low FPS
            config.capturesAudio = true
            config.sampleRate = 48000
            config.channelCount = 2

            // Set up temporary file output for system audio
            let tempDir = FileManager.default.temporaryDirectory
            let filename = generateFilename(meetingTitle: meetingTitle)
            let sysFileName = "\(filename)_sys.wav"
            tempURL = tempDir.appendingPathComponent(sysFileName)
            
            guard let tempURL = tempURL else {
                errorMessage = "Failed to create temporary file path"
                return
            }
            
            // Remove existing system audio file if any
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try? FileManager.default.removeItem(at: tempURL)
            }
            
            // Set up microphone temporary file
            let micFileName = "\(filename)_mic.wav"
            micTempURL = tempDir.appendingPathComponent(micFileName)

            // Prepare mic recorder settings (same as system audio)
            let micSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            
            print("🎤 Initializing microphone recorder...")
            print("   Mic temp file: \(micTempURL?.path ?? "nil")")
            
            do {
                if let micURL = micTempURL {
                    // Remove existing mic file if any
                    if FileManager.default.fileExists(atPath: micURL.path) {
                        try FileManager.default.removeItem(at: micURL)
                    }
                    
                    micRecorder = try AVAudioRecorder(url: micURL, settings: micSettings)
                    micRecorder?.delegate = self
                    print("   📝 Mic recorder created")
                    
                    let prepared = micRecorder?.prepareToRecord() ?? false
                    print("   ✅ Prepared to record: \(prepared)")
                    
                    let recording = micRecorder?.record() ?? false
                    print("   ⏺️ Recording started: \(recording)")
                    
                    if recording {
                        print("   ✅ Microphone recording active")
                    } else {
                        errorMessage = "Failed to start microphone recording"
                        print("   ❌ Microphone recording failed")
                    }
                }
            } catch {
                errorMessage = "Failed to start mic recorder: \(error.localizedDescription)"
                print("   ❌ Mic recorder error: \(error.localizedDescription)")
            }
            
            // Create asset writer for WAV
            assetWriter = try AVAssetWriter(outputURL: tempURL, fileType: .wav)
            
            // Audio input settings for Linear PCM (WAV)
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true
            
            if let audioInput = audioInput {
                if assetWriter?.canAdd(audioInput) == true {
                    assetWriter?.add(audioInput)
                }
            }
            
            // Start writing
            if assetWriter?.startWriting() == false {
                errorMessage = "Failed to start writing: \(assetWriter?.error?.localizedDescription ?? "Unknown error")"
                return
            }
            
            assetWriter?.startSession(atSourceTime: CMTime.zero) // Start immediately for audio
            
            // Create and start stream
            stream = SCStream(filter: filter, configuration: config, delegate: nil)
            
            // Add stream output - ONLY audio
            try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
            
            try await stream?.startCapture()
            
            isRecording = true
            errorMessage = nil
            
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    // Stop recording
    func stopRecording() async {
        print("🛑 stopRecording called, isRecording: \(isRecording)")
        guard isRecording else {
            print("⚠️ Not recording, returning early")
            return
        }

        print("✅ Proceeding with stop recording")
        
        // Ensure we always set isRecording to false when this function completes
        defer {
            print("🔄 Defer block executing - setting isRecording to false")
            DispatchQueue.main.async {
                self.isRecording = false
                self.fetchRecordings()
                print("✅ isRecording set to false on main thread")
            }
        }
        
        do {
            print("🎥 Stopping stream capture...")
            try await stream?.stopCapture()
            stream = nil
            print("✅ Stream stopped")
            
            // Finish writing system audio
            print("🎵 Marking audio input as finished...")
            audioInput?.markAsFinished()
            
            print("💾 Finishing asset writer...")
            await assetWriter?.finishWriting()
            print("✅ Asset writer finished, status: \(assetWriter?.status.rawValue ?? -1)")
            
            // Stop microphone recorder
            print("🎤 Stopping mic recorder...")
            micRecorder?.stop()
            print("✅ Mic recorder stopped")
            
            // Capture the temporary URLs so we can safely clear the stored properties before awaiting work
            let systemURL = tempURL
            let microphoneURL = micTempURL
            tempURL = nil
            micTempURL = nil

            // Mix system and mic audio into a single file
            if let sysURL = systemURL, let micURL = microphoneURL {
                print("🔀 Starting audio mixing...")
                print("   System URL: \(sysURL.path)")
                print("   Mic URL: \(micURL.path)")
                
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let finalFileName = "\(generateFilename(meetingTitle: currentMeetingTitle)).wav"
                let destinationURL = documentsURL.appendingPathComponent(finalFileName)

                // Clear meeting title after using it
                currentMeetingTitle = nil
                
                print("   Destination: \(destinationURL.path)")
                
                // Remove existing destination if any
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try? FileManager.default.removeItem(at: destinationURL)
                    print("   🗑️ Removed existing file")
                }
                
                do {
                    print("   🎶 Calling mixAudioFiles...")
                    try await mixAudioFiles(systemURL: sysURL, micURL: micURL, destinationURL: destinationURL)
                    print("   ✅ Audio mixing complete")
                    DispatchQueue.main.async {
                        self.lastRecordingPath = destinationURL.path
                        // Update recordings immediately so UI shows the new file without waiting
                        self.fetchRecordings()
                    }
                } catch {
                    print("   ❌ Audio mixing failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to mix audio: \(error.localizedDescription)"
                    }
                }
            } else {
                print("⚠️ Missing URLs - sysURL: \(systemURL?.path ?? "nil"), micURL: \(microphoneURL?.path ?? "nil")")
            }
            
            // Clean up temporary files
            print("🧹 Cleaning up temporary files...")
            if let sysURL = systemURL {
                try? FileManager.default.removeItem(at: sysURL)
                print("   ✅ Removed system temp file")
            }
            if let micURL = microphoneURL {
                try? FileManager.default.removeItem(at: micURL)
                print("   ✅ Removed mic temp file")
            }
            
            print("✅ Stop recording completed successfully")
            
        } catch {
            print("❌ Error in stopRecording: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to save recording: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchRecordings() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            // Include all .wav files
            let recordings = fileURLs.filter {
                $0.pathExtension.lowercased() == "wav"
            }

            DispatchQueue.main.async {
                self.recordings = recordings.sorted(by: { $0.creationDate > $1.creationDate })
            }
        } catch {
            print("Error fetching recordings: \(error)")
        }
    }
    
    func deleteRecording(at url: URL) {
        do {
            // Delete the audio file
            try FileManager.default.removeItem(at: url)

            // Also delete associated transcription/summary if they exist
            try? transcriptionService.deleteTranscription(for: url)
            try? transcriptionService.deleteSummary(for: url)

            fetchRecordings()
        } catch {
            print("Error deleting recording: \(error)")
            errorMessage = "Failed to delete recording: \(error.localizedDescription)"
        }
    }
    
    func renameRecording(from oldURL: URL, to newName: String) {
        let fileManager = FileManager.default
        let directory = oldURL.deletingLastPathComponent()

        // Use the name exactly as typed
        let newFileName = "\(newName).wav"
        let newURL = directory.appendingPathComponent(newFileName)

        print("📝 Renaming \(oldURL.lastPathComponent) to \(newFileName)")

        do {
            // Rename the audio file
            try fileManager.moveItem(at: oldURL, to: newURL)

            // Rename associated transcription if it exists
            if transcriptionService.transcriptionExists(for: oldURL) {
                if let oldTranscription = transcriptionService.loadTranscription(for: oldURL) {
                    try? transcriptionService.deleteTranscription(for: oldURL)
                    _ = try? transcriptionService.saveTranscription(oldTranscription, for: newURL)
                }
            }

            // Rename summary if it exists
            if transcriptionService.summaryExists(for: oldURL) {
                if let oldSummary = transcriptionService.loadSummary(for: oldURL) {
                    try? transcriptionService.deleteSummary(for: oldURL)
                    _ = try? transcriptionService.saveSummary(oldSummary, for: newURL)
                }
            }

            print("✅ Rename successful")
            fetchRecordings()
        } catch {
            print("❌ Error renaming recording: \(error)")
            errorMessage = "Failed to rename recording: \(error.localizedDescription)"
        }
    }
    
    // Format date for filename
    private func formatDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }

    // Generate filename with optional meeting title
    private func generateFilename(meetingTitle: String?) -> String {
        let dateString = formatDate()

        if let title = meetingTitle, !title.isEmpty {
            // Clean the meeting title for filename
            let cleanTitle = title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: "\\", with: "-")
                .replacingOccurrences(of: "|", with: "-")
                .replacingOccurrences(of: "?", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .prefix(50) // Limit to 50 characters

            return "\(dateString)_\(cleanTitle)"
        } else {
            return "Recording_\(dateString)"
        }
    }
    
    // MARK: - Audio Mixing
    private func mixAudioFiles(systemURL: URL, micURL: URL, destinationURL: URL) async throws {
        print("   📂 Loading system audio from: \(systemURL.path)")
        let systemFile = try AVAudioFile(forReading: systemURL)
        let systemFormat = systemFile.processingFormat
        let systemFrameCount = UInt32(systemFile.length)
        guard let systemBuffer = AVAudioPCMBuffer(pcmFormat: systemFormat, frameCapacity: systemFrameCount) else {
            throw NSError(domain: "AudioMix", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create system buffer"])
        }
        try systemFile.read(into: systemBuffer)
        print("   ✅ System audio loaded: \(systemFrameCount) frames")
        
        print("   📂 Loading mic audio from: \(micURL.path)")
        let micFile = try AVAudioFile(forReading: micURL)
        let micFormat = micFile.processingFormat
        let micFrameCount = UInt32(micFile.length)
        guard let micBuffer = AVAudioPCMBuffer(pcmFormat: micFormat, frameCapacity: micFrameCount) else {
            throw NSError(domain: "AudioMix", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create mic buffer"])
        }
        try micFile.read(into: micBuffer)
        print("   ✅ Mic audio loaded: \(micFrameCount) frames")
        
        // Use system format as output format (should match wav settings)
        let outputFormat = systemFormat
        print("   📝 Creating output file with format: \(outputFormat.sampleRate)Hz, \(outputFormat.channelCount)ch")
        let outputFile = try AVAudioFile(forWriting: destinationURL, settings: outputFormat.settings)
        
        // Mix audio: write frame-by-frame, summing both channels
        let maxFrames = max(systemFrameCount, micFrameCount)
        guard let mixedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: maxFrames) else {
            throw NSError(domain: "AudioMix", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create mixed buffer"])
        }
        
        if let systemData = systemBuffer.floatChannelData,
           let micData = micBuffer.floatChannelData,
           let mixedData = mixedBuffer.floatChannelData {
            
            let channelCount = Int(outputFormat.channelCount)
            
            // Mix samples: iterate through frames and sum corresponding samples
            for frame in 0..<Int(maxFrames) {
                for channel in 0..<channelCount {
                    var mixed: Float = 0
                    
                    if frame < Int(systemFrameCount) {
                        mixed += systemData[channel][frame]
                    }
                    if frame < Int(micFrameCount) {
                        mixed += micData[channel][frame]
                    }
                    
                    // Soft clipping to prevent distortion
                    if mixed > 1.0 {
                        mixed = 1.0
                    } else if mixed < -1.0 {
                        mixed = -1.0
                    }
                    
                    mixedData[channel][frame] = mixed
                }
            }
        }
        
        mixedBuffer.frameLength = maxFrames
        print("   🎵 Mixed \(maxFrames) frames")
        
        // Write mixed buffer to output file
        try outputFile.write(from: mixedBuffer)
        print("   💾 Wrote mixed audio to: \(destinationURL.path)")
    }
}

// MARK: - AVAudioRecorderDelegate

extension ScreenRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🎤 Mic recorder finished: success=\(flag)")
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("🎤 Mic recorder error: \(error.localizedDescription)")
        }
    }
}

// MARK: - SCStreamOutput

extension ScreenRecorder: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Wrap CMSampleBuffer to make it safe for async context
        // CMSampleBuffer is reference-counted and safe to use across threads
        let buffer = UnsafeSendable(sampleBuffer)

        Task { @MainActor in
            switch type {
            case .audio:
                // If pre-buffering, store samples in buffer
                if isPreBuffering {
                    // Append buffer directly (ARC handles memory management)
                    self.preBufferData.append(buffer.value)

                    // Calculate total duration and remove old samples if > 30 seconds
                    var totalDuration: TimeInterval = 0
                    for sample in self.preBufferData {
                        let duration = CMTimeGetSeconds(sample.duration)
                        totalDuration += duration
                    }

                    // Remove oldest samples if we exceed 30 seconds
                    while totalDuration > self.preBufferDuration && self.preBufferData.count > 1 {
                        let removedBuffer = self.preBufferData.removeFirst()
                        let removedDuration = CMTimeGetSeconds(removedBuffer.duration)
                        totalDuration -= removedDuration
                        // ARC automatically releases removedBuffer
                    }
                }
                // If actively recording, write to file
                else if isRecording,
                        let assetWriter = assetWriter,
                        assetWriter.status == .writing,
                        let audioInput = audioInput,
                        audioInput.isReadyForMoreMediaData {
                    audioInput.append(buffer.value)
                }
            default:
                break
            }
        }
    }
}

// Helper to make non-Sendable types work with Task
private struct UnsafeSendable<T>: @unchecked Sendable {
    nonisolated(unsafe) let value: T
    nonisolated init(_ value: T) {
        self.value = value
    }
}

extension URL {
    var creationDate: Date {
        return (try? resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
    }
}
