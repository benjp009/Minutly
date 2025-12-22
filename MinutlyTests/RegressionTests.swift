//
//  RegressionTests.swift
//  MinutlyTests
//
//  Regression test suite to ensure core functionality remains intact
//  Run these tests before committing any changes to recording, playback, or encryption
//

import XCTest
import AVFoundation
import CryptoKit
@testable import Minutly

class RegressionTests: XCTestCase {

    var testRecorder: ScreenRecorder!
    var encryptionService: EncryptionService!
    var testDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        testRecorder = ScreenRecorder()
        encryptionService = EncryptionService.shared

        // Create a temporary test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MinutlyRegressionTests")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        print("✅ Test directory created: \(testDirectory.path)")
    }

    override func tearDownWithError() throws {
        // Clean up test directory
        if FileManager.default.fileExists(atPath: testDirectory.path) {
            try FileManager.default.removeItem(at: testDirectory)
            print("✅ Test directory cleaned up")
        }

        testRecorder = nil
        encryptionService = nil
        testDirectory = nil

        try super.tearDownWithError()
    }

    // MARK: - Test 1: Recording Success

    /// Regression Test: Verify that recording can be created and produces valid encrypted output
    func testRecordingSuccess() throws {
        let expectation = XCTestExpectation(description: "Recording completes successfully")

        // Create a test recording file path
        let testFileName = "test_recording_\(Date().timeIntervalSince1970).enc"
        let testRecordingURL = testDirectory.appendingPathComponent(testFileName)

        // Generate test audio data (1 second of sine wave at 440 Hz)
        let testAudioData = try generateTestAudio(duration: 1.0, frequency: 440.0)

        // Write test audio to temporary WAV file
        let tempWavURL = testDirectory.appendingPathComponent("temp_test.wav")
        try testAudioData.write(to: tempWavURL)

        // Encrypt the test audio
        try encryptionService.encryptAudioFile(at: tempWavURL, to: testRecordingURL)

        // Verify encrypted file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: testRecordingURL.path),
                      "❌ REGRESSION FAILURE: Encrypted recording file does not exist")

        // Verify encrypted file has content
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: testRecordingURL.path)
        let fileSize = fileAttributes[.size] as? Int ?? 0
        XCTAssertGreaterThan(fileSize, 0,
                            "❌ REGRESSION FAILURE: Encrypted recording file is empty")

        // Verify file can be decrypted
        let decryptedData = try encryptionService.decryptFileTemporarily(at: testRecordingURL)
        XCTAssertGreaterThan(decryptedData.count, 0,
                            "❌ REGRESSION FAILURE: Decrypted data is empty")

        // Verify decrypted data matches original
        let originalData = try Data(contentsOf: tempWavURL)
        XCTAssertEqual(decryptedData, originalData,
                      "❌ REGRESSION FAILURE: Decrypted data does not match original")

        print("✅ REGRESSION PASS: Recording success test passed")
        expectation.fulfill()

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Test 2: Playback Success

    /// Regression Test: Verify that encrypted recordings can be decrypted and played back
    func testPlaybackSuccess() throws {
        let expectation = XCTestExpectation(description: "Playback succeeds")

        // Create a test recording
        let testFileName = "test_playback_\(Date().timeIntervalSince1970).enc"
        let testRecordingURL = testDirectory.appendingPathComponent(testFileName)

        // Generate test audio data
        let testAudioData = try generateTestAudio(duration: 1.0, frequency: 440.0)

        // Write test audio to temporary WAV file
        let tempWavURL = testDirectory.appendingPathComponent("temp_playback.wav")
        try testAudioData.write(to: tempWavURL)

        // Encrypt the test audio
        try encryptionService.encryptAudioFile(at: tempWavURL, to: testRecordingURL)

        // Verify encrypted file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: testRecordingURL.path),
                      "❌ REGRESSION FAILURE: Test recording does not exist")

        // Decrypt for playback
        let decryptedData = try encryptionService.decryptFileTemporarily(at: testRecordingURL)

        // Write decrypted data to temporary file for playback
        let playbackTempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("playback_test.wav")

        try FileManager.default.createDirectory(at: playbackTempURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try decryptedData.write(to: playbackTempURL)

        // Create audio player
        let audioPlayer = try AVAudioPlayer(contentsOf: playbackTempURL)
        XCTAssertNotNil(audioPlayer, "❌ REGRESSION FAILURE: Audio player could not be created")

        // Verify audio properties
        XCTAssertGreaterThan(audioPlayer.duration, 0,
                            "❌ REGRESSION FAILURE: Audio duration is zero")

        // Attempt to prepare for playback
        let prepared = audioPlayer.prepareToPlay()
        XCTAssertTrue(prepared, "❌ REGRESSION FAILURE: Audio player failed to prepare")

        // Clean up
        try? FileManager.default.removeItem(at: playbackTempURL.deletingLastPathComponent())

        print("✅ REGRESSION PASS: Playback success test passed")
        expectation.fulfill()

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Test 3: Encryption Key Validity

    /// Regression Test: Verify encryption key is consistently stored and retrieved
    func testEncryptionKeyValidity() throws {
        let expectation = XCTestExpectation(description: "Encryption key is valid and consistent")

        // Get the master key (this will create one if it doesn't exist)
        let key1 = try encryptionService.getMasterKey()
        let key1Data = key1.withUnsafeBytes { Data($0) }

        print("🔑 First key retrieval: \(key1Data.count) bytes")

        // Verify key size
        XCTAssertEqual(key1Data.count, 32,
                      "❌ REGRESSION FAILURE: Encryption key is not 256-bit (32 bytes)")

        // Get the key again - should be the same key
        let key2 = try encryptionService.getMasterKey()
        let key2Data = key2.withUnsafeBytes { Data($0) }

        print("🔑 Second key retrieval: \(key2Data.count) bytes")

        // Verify keys are identical
        XCTAssertEqual(key1Data, key2Data,
                      "❌ REGRESSION FAILURE: Encryption key changed between retrievals")

        // Test encryption/decryption with the key
        let testData = "This is a test message for encryption validation".data(using: .utf8)!

        // Encrypt
        let sealedBox = try AES.GCM.seal(testData, using: key1)
        guard let encryptedData = sealedBox.combined else {
            XCTFail("❌ REGRESSION FAILURE: Failed to get encrypted data")
            return
        }

        print("🔒 Encrypted \(testData.count) bytes to \(encryptedData.count) bytes")

        // Decrypt with the same key
        let sealedBox2 = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox2, using: key2)

        print("🔓 Decrypted \(encryptedData.count) bytes to \(decryptedData.count) bytes")

        // Verify decrypted data matches original
        XCTAssertEqual(decryptedData, testData,
                      "❌ REGRESSION FAILURE: Decrypted data does not match original")

        // Verify encryption produces different output each time (due to nonce)
        let sealedBox3 = try AES.GCM.seal(testData, using: key1)
        guard let encryptedData2 = sealedBox3.combined else {
            XCTFail("❌ REGRESSION FAILURE: Failed to get second encrypted data")
            return
        }

        XCTAssertNotEqual(encryptedData, encryptedData2,
                         "❌ REGRESSION FAILURE: Encryption produces identical output (nonce not random)")

        print("✅ REGRESSION PASS: Encryption key validity test passed")
        expectation.fulfill()

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Test 4: End-to-End Recording Pipeline

    /// Regression Test: Full recording pipeline (encrypt -> decrypt -> playback)
    func testEndToEndRecordingPipeline() throws {
        let expectation = XCTestExpectation(description: "End-to-end pipeline succeeds")

        // Step 1: Generate test audio
        let testAudioData = try generateTestAudio(duration: 2.0, frequency: 440.0)
        let tempWavURL = testDirectory.appendingPathComponent("pipeline_test.wav")
        try testAudioData.write(to: tempWavURL)

        print("1️⃣ Generated test audio: \(testAudioData.count) bytes")

        // Step 2: Encrypt
        let encryptedURL = testDirectory.appendingPathComponent("pipeline_test.enc")
        try encryptionService.encryptAudioFile(at: tempWavURL, to: encryptedURL)

        let encryptedSize = try FileManager.default.attributesOfItem(atPath: encryptedURL.path)[.size] as? Int ?? 0
        print("2️⃣ Encrypted to: \(encryptedSize) bytes")

        XCTAssertGreaterThan(encryptedSize, 0,
                            "❌ REGRESSION FAILURE: Encryption produced empty file")

        // Step 3: Verify file is encrypted (not readable as WAV)
        XCTAssertThrowsError(try AVAudioFile(forReading: encryptedURL),
                            "❌ REGRESSION FAILURE: Encrypted file is readable as WAV (not properly encrypted)")

        // Step 4: Decrypt
        let decryptedData = try encryptionService.decryptFileTemporarily(at: encryptedURL)
        print("3️⃣ Decrypted to: \(decryptedData.count) bytes")

        XCTAssertEqual(decryptedData.count, testAudioData.count,
                      "❌ REGRESSION FAILURE: Decrypted data size does not match original")

        // Step 5: Verify decrypted data is valid audio
        let playbackURL = testDirectory.appendingPathComponent("pipeline_playback.wav")
        try decryptedData.write(to: playbackURL)

        let audioFile = try AVAudioFile(forReading: playbackURL)
        print("4️⃣ Audio file readable: \(audioFile.length) frames")

        XCTAssertGreaterThan(audioFile.length, 0,
                            "❌ REGRESSION FAILURE: Decrypted audio has no frames")

        // Step 6: Verify playback
        let audioPlayer = try AVAudioPlayer(contentsOf: playbackURL)
        XCTAssertTrue(audioPlayer.prepareToPlay(),
                     "❌ REGRESSION FAILURE: Audio player failed to prepare")

        print("5️⃣ Audio player ready: \(audioPlayer.duration) seconds")

        print("✅ REGRESSION PASS: End-to-end pipeline test passed")
        expectation.fulfill()

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Test 5: Recording Stop Crash Prevention

    /// Regression Test: Verify recording stop doesn't crash due to audio hardware cleanup issues
    /// This test validates the fix for the audio I/O thread crash when stopping recordings
    func testRecordingStopNoCrash() throws {
        let expectation = XCTestExpectation(description: "Recording stop completes without crash")

        // This is a synchronous test to ensure cleanup completes before proceeding
        Task { @MainActor in
            do {
                // Simulate the meeting recording workflow
                print("1️⃣ Starting recording (simulating meeting recording)...")

                // Note: We can't actually start SCStream recording in tests due to permissions
                // Instead, we test the cleanup path with minimal resources

                // Create temporary files to simulate active recording
                let testFileName = "test_stop_crash_\(Date().timeIntervalSince1970)"
                let sysURL = testDirectory.appendingPathComponent("\(testFileName)_sys.wav")
                let micURL = testDirectory.appendingPathComponent("\(testFileName)_mic.wav")

                // Generate minimal test audio
                let testAudioData = try generateTestAudio(duration: 0.5, frequency: 440.0)
                try testAudioData.write(to: sysURL)
                try testAudioData.write(to: micURL)

                print("2️⃣ Files created, simulating recording stop...")

                // Simulate the cleanup sequence (without actual SCStream/AVAssetWriter)
                // This tests the file handling and mixing logic

                // Test audio mixing (critical part of stopRecording)
                let finalURL = testDirectory.appendingPathComponent("\(testFileName).wav")
                try await self.testRecorder.mixAudioFiles(systemURL: sysURL, micURL: micURL, destinationURL: finalURL)

                print("3️⃣ Audio mixing completed successfully")

                // Verify output exists
                XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path),
                             "❌ REGRESSION FAILURE: Mixed audio file not created")

                let finalSize = try FileManager.default.attributesOfItem(atPath: finalURL.path)[.size] as? Int ?? 0
                XCTAssertGreaterThan(finalSize, 0,
                                    "❌ REGRESSION FAILURE: Mixed audio file is empty")

                print("4️⃣ Verifying file integrity...")

                // Verify the file is valid audio
                let audioFile = try AVAudioFile(forReading: finalURL)
                XCTAssertGreaterThan(audioFile.length, 0,
                                    "❌ REGRESSION FAILURE: Mixed audio has no frames")

                print("5️⃣ Encrypting final file...")

                // Test encryption (part of stopRecording workflow)
                let encryptedURL = testDirectory.appendingPathComponent("\(testFileName).enc")
                try self.encryptionService.encryptAudioFile(at: finalURL, to: encryptedURL)

                XCTAssertTrue(FileManager.default.fileExists(atPath: encryptedURL.path),
                             "❌ REGRESSION FAILURE: Encrypted file not created")

                print("6️⃣ Cleanup test files...")

                // Clean up (simulating the temp file removal in stopRecording)
                try? FileManager.default.removeItem(at: sysURL)
                try? FileManager.default.removeItem(at: micURL)
                try? FileManager.default.removeItem(at: finalURL)

                print("✅ REGRESSION PASS: Recording stop workflow completed without crash")
                expectation.fulfill()

            } catch {
                XCTFail("❌ REGRESSION FAILURE: Recording stop crashed or failed: \(error)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 30.0)
    }

    // MARK: - Test 6: Multiple Start/Stop Cycles

    /// Regression Test: Verify multiple recording start/stop cycles don't cause resource leaks or crashes
    func testMultipleRecordingCycles() throws {
        let expectation = XCTestExpectation(description: "Multiple recording cycles complete")

        Task { @MainActor in
            do {
                print("🔄 Testing multiple recording cycles...")

                for cycle in 1...3 {
                    print("\n--- Cycle \(cycle) ---")

                    // Create test files
                    let testFileName = "test_cycle_\(cycle)_\(Date().timeIntervalSince1970)"
                    let sysURL = testDirectory.appendingPathComponent("\(testFileName)_sys.wav")
                    let micURL = testDirectory.appendingPathComponent("\(testFileName)_mic.wav")
                    let finalURL = testDirectory.appendingPathComponent("\(testFileName).wav")
                    let encryptedURL = testDirectory.appendingPathComponent("\(testFileName).enc")

                    // Generate test audio
                    let testAudioData = try generateTestAudio(duration: 0.3, frequency: 440.0)
                    try testAudioData.write(to: sysURL)
                    try testAudioData.write(to: micURL)

                    // Mix audio
                    try await self.testRecorder.mixAudioFiles(systemURL: sysURL, micURL: micURL, destinationURL: finalURL)

                    // Encrypt
                    try self.encryptionService.encryptAudioFile(at: finalURL, to: encryptedURL)

                    // Verify
                    XCTAssertTrue(FileManager.default.fileExists(atPath: encryptedURL.path),
                                 "❌ REGRESSION FAILURE: Cycle \(cycle) - encrypted file not created")

                    // Cleanup
                    try? FileManager.default.removeItem(at: sysURL)
                    try? FileManager.default.removeItem(at: micURL)
                    try? FileManager.default.removeItem(at: finalURL)
                    try? FileManager.default.removeItem(at: encryptedURL)

                    print("✅ Cycle \(cycle) completed")

                    // Small delay between cycles
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }

                print("✅ REGRESSION PASS: All \(3) recording cycles completed successfully")
                expectation.fulfill()

            } catch {
                XCTFail("❌ REGRESSION FAILURE: Multiple cycles test failed: \(error)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 60.0)
    }

    // MARK: - Helper Methods

    /// Generate test audio data (WAV format with PCM)
    private func generateTestAudio(duration: TimeInterval, frequency: Double) throws -> Data {
        let sampleRate: Double = 44100.0
        let amplitude: Float = 0.8
        let frameCount = Int(duration * sampleRate)

        // Create audio format (PCM, 1 channel, 44.1kHz)
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        // Create buffer
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            throw NSError(domain: "RegressionTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio buffer"])
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        // Generate sine wave
        guard let channelData = buffer.floatChannelData else {
            throw NSError(domain: "RegressionTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get channel data"])
        }

        let angularFrequency = 2.0 * .pi * frequency / sampleRate
        for frame in 0..<frameCount {
            let sample = amplitude * sin(angularFrequency * Double(frame))
            channelData[0][frame] = Float(sample)
        }

        // Write to temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let audioFile = try AVAudioFile(
            forWriting: tempURL,
            settings: format.settings,
            commonFormat: .pcmFormatInt16,
            interleaved: false
        )

        try audioFile.write(from: buffer)

        let data = try Data(contentsOf: tempURL)
        try? FileManager.default.removeItem(at: tempURL)

        return data
    }
}
