//
//  EncryptionService.swift
//  Minutly
//
//  Created by Benjamin Patin on 08/12/2025.
//

import Foundation
import CryptoKit
import Security

class EncryptionService {
    static let shared = EncryptionService()

    private let keychainService = KeychainService.shared
    private let keyIdentifier = "com.minutly.encryption_key"

    // MARK: - Key Management

    /// Get or create the master encryption key stored in Keychain
    func getMasterKey() throws -> SymmetricKey {
        // Try to retrieve existing key from Keychain
        if let keyBase64 = try keychainService.retrieveAPIKey(for: keyIdentifier) {
            // The key is stored as base64, so we need to decode it
            if let keyData = Data(base64Encoded: keyBase64), keyData.count == 32 {
                print("🔑 Retrieved existing encryption key from Keychain")
                return SymmetricKey(data: keyData)
            } else {
                print("⚠️ Found key in Keychain but it's invalid (wrong size or encoding), creating new key")
            }
        }

        // Create a new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        // Store in Keychain as base64
        try keychainService.saveAPIKey(keyData.base64EncodedString(), for: keyIdentifier)
        print("✅ Created and stored new encryption master key")

        return newKey
    }

    // MARK: - Encryption

    /// File format constants for chunked encryption
    private static let magicHeader = "MNTLY001"  // 8 bytes: Format identifier + version
    private static let chunkSize = 1_048_576     // 1 MB chunks for streaming
    private static let headerSize = 16           // 8 (magic) + 4 (chunk size) + 4 (chunk count)

    /// Encrypt audio file using chunked streaming (memory-efficient for large files)
    /// Memory footprint: ~2 MB constant vs 2.76 GB for 1-hour recording with old approach
    func encryptAudioFile(at sourceURL: URL, to destinationURL: URL) throws {
        print("🔐 Starting chunked encryption for: \(sourceURL.lastPathComponent)")

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        guard let fileSize = attributes[.size] as? Int else {
            throw EncryptionError.fileOperationFailed("Could not get file size")
        }

        print("   📊 File size: \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))")

        // Calculate chunk count
        let chunkCount = (fileSize + Self.chunkSize - 1) / Self.chunkSize
        print("   📦 Will process \(chunkCount) chunks of \(ByteCountFormatter.string(fromByteCount: Int64(Self.chunkSize), countStyle: .file)) each")

        // Get encryption key
        let key = try getMasterKey()

        // Open input file for reading
        guard let inputHandle = FileHandle(forReadingAtPath: sourceURL.path) else {
            throw EncryptionError.fileNotFound
        }
        defer { try? inputHandle.close() }

        // Create output file
        FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
        guard let outputHandle = FileHandle(forWritingAtPath: destinationURL.path) else {
            throw EncryptionError.fileOperationFailed("Could not create output file")
        }
        defer { try? outputHandle.close() }

        // Write header
        var header = Data()
        header.append(Self.magicHeader.data(using: .utf8)!)  // 8 bytes
        header.append(withUnsafeBytes(of: UInt32(Self.chunkSize).bigEndian) { Data($0) })  // 4 bytes
        header.append(withUnsafeBytes(of: UInt32(chunkCount).bigEndian) { Data($0) })  // 4 bytes
        outputHandle.write(header)

        // Process chunks
        var processedBytes = 0
        var chunkIndex = 0

        while processedBytes < fileSize {
            let remainingBytes = fileSize - processedBytes
            let currentChunkSize = min(Self.chunkSize, remainingBytes)

            // Read chunk
            guard let chunkData = try? inputHandle.read(upToCount: currentChunkSize) else {
                throw EncryptionError.fileOperationFailed("Failed to read chunk \(chunkIndex)")
            }

            // Encrypt chunk using AES-GCM
            let sealedBox = try AES.GCM.seal(chunkData, using: key)
            guard let encryptedChunk = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }

            // Write encrypted chunk (includes nonce + ciphertext + 16-byte auth tag)
            outputHandle.write(encryptedChunk)

            processedBytes += currentChunkSize
            chunkIndex += 1

            // Log progress every 100 chunks (~100 MB)
            if chunkIndex % 100 == 0 {
                let progress = Double(processedBytes) / Double(fileSize) * 100.0
                print("   ⏳ Encryption progress: \(String(format: "%.1f", progress))% (\(chunkIndex)/\(chunkCount) chunks)")
            }
        }

        print("   ✅ Encrypted \(chunkCount) chunks (\(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)))")
        print("   💾 Output saved to: \(destinationURL.lastPathComponent)")
        print("   🎉 Chunked encryption complete - constant memory usage")
    }

    /// Encrypt arbitrary data using AES-GCM
    private func encryptData(_ plaintext: Data) throws -> Data {
        let key = try getMasterKey()
        let sealedBox = try AES.GCM.seal(plaintext, using: key)

        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }

        return combined
    }

    // MARK: - Decryption

    /// Decrypt audio file with automatic format detection (supports both legacy and chunked formats)
    /// Memory footprint: ~2 MB for chunked format, full file for legacy format
    func decryptAudioFile(at encryptedURL: URL) throws -> Data {
        // Detect file format by checking for magic header
        if let header = try? Data(contentsOf: encryptedURL, options: .alwaysMapped).prefix(8),
           let headerString = String(data: header, encoding: .utf8),
           headerString == Self.magicHeader {
            // New chunked format - use streaming decryption
            print("🔓 Detected chunked encrypted format, using streaming decryption")
            return try decryptAudioFileChunked(at: encryptedURL)
        } else {
            // Legacy format - load entire file (backwards compatibility)
            print("🔓 Detected legacy encrypted format, using full-file decryption")
            print("   ⚠️ Warning: Legacy format loads entire file into memory")
            let encryptedData = try Data(contentsOf: encryptedURL)
            return try decryptData(encryptedData)
        }
    }

    /// Decrypt chunked audio file using streaming (memory-efficient)
    private func decryptAudioFileChunked(at encryptedURL: URL) throws -> Data {
        print("🔓 Starting chunked decryption for: \(encryptedURL.lastPathComponent)")

        // Get encryption key
        let key = try getMasterKey()

        // Open encrypted file
        guard let inputHandle = FileHandle(forReadingAtPath: encryptedURL.path) else {
            throw EncryptionError.fileNotFound
        }
        defer { try? inputHandle.close() }

        // Read and validate header
        guard let headerData = try? inputHandle.read(upToCount: Self.headerSize),
              headerData.count == Self.headerSize else {
            throw EncryptionError.invalidCiphertext
        }

        let magic = String(data: headerData.prefix(8), encoding: .utf8)
        guard magic == Self.magicHeader else {
            throw EncryptionError.invalidCiphertext
        }

        let chunkSize = Int(UInt32(bigEndian: headerData.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: UInt32.self) }))
        let chunkCount = Int(UInt32(bigEndian: headerData.subdata(in: 12..<16).withUnsafeBytes { $0.load(as: UInt32.self) }))

        print("   📊 Chunks: \(chunkCount), Chunk size: \(ByteCountFormatter.string(fromByteCount: Int64(chunkSize), countStyle: .file))")

        // Decrypt chunks into accumulated data
        var decryptedData = Data()
        decryptedData.reserveCapacity(chunkCount * chunkSize)

        for chunkIndex in 0..<chunkCount {
            // Calculate encrypted chunk size: AES-GCM adds 12 (nonce) + 16 (tag) = 28 bytes overhead
            let isLastChunk = (chunkIndex == chunkCount - 1)
            let baseChunkSize = chunkSize + 28  // Overhead for AES-GCM combined format

            // For last chunk, read all remaining data (may be smaller)
            let encryptedChunk: Data
            if isLastChunk {
                // Read all remaining data for last chunk
                guard let remaining = try? inputHandle.readToEnd() else {
                    throw EncryptionError.fileOperationFailed("Failed to read final chunk \(chunkIndex)")
                }
                encryptedChunk = remaining
            } else {
                guard let chunk = try? inputHandle.read(upToCount: baseChunkSize),
                      chunk.count == baseChunkSize else {
                    throw EncryptionError.fileOperationFailed("Failed to read chunk \(chunkIndex)")
                }
                encryptedChunk = chunk
            }

            // Decrypt chunk
            guard let sealedBox = try? AES.GCM.SealedBox(combined: encryptedChunk) else {
                throw EncryptionError.invalidCiphertext
            }

            let decryptedChunk = try AES.GCM.open(sealedBox, using: key)
            decryptedData.append(decryptedChunk)

            // Log progress every 100 chunks
            if (chunkIndex + 1) % 100 == 0 {
                let progress = Double(chunkIndex + 1) / Double(chunkCount) * 100.0
                print("   ⏳ Decryption progress: \(String(format: "%.1f", progress))% (\(chunkIndex + 1)/\(chunkCount) chunks)")
            }
        }

        print("   ✅ Decrypted \(chunkCount) chunks (\(ByteCountFormatter.string(fromByteCount: Int64(decryptedData.count), countStyle: .file)))")
        print("   🎉 Chunked decryption complete - constant memory usage")

        return decryptedData
    }

    /// Decrypt arbitrary data using AES-GCM
    private func decryptData(_ ciphertext: Data) throws -> Data {
        let key = try getMasterKey()

        guard let sealedBox = try? AES.GCM.SealedBox(combined: ciphertext) else {
            throw EncryptionError.invalidCiphertext
        }

        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - File Operations

    /// Encrypt a file in place and delete the original
    func encryptFileInPlace(at fileURL: URL) throws {
        let tempURL = fileURL.appendingPathComponent(".encrypting")

        // Encrypt to temporary file
        try encryptAudioFile(at: fileURL, to: tempURL)

        // Replace original with encrypted version
        let finalEncryptedURL = fileURL.appendingPathExtension("encrypted")
        try FileManager.default.removeItem(at: finalEncryptedURL)
        try FileManager.default.moveItem(at: tempURL, to: finalEncryptedURL)

        // Delete original
        try FileManager.default.removeItem(at: fileURL)
    }

    /// Decrypt a file temporarily and return the data
    func decryptFileTemporarily(at encryptedURL: URL) throws -> Data {
        return try decryptAudioFile(at: encryptedURL)
    }

    /// Check if a file is encrypted
    func isFileEncrypted(_ url: URL) -> Bool {
        return url.pathExtension == "encrypted"
    }

    /// Get encryption status for a file
    func getEncryptionStatus(_ url: URL) -> EncryptionStatus {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: url.path) {
            return .notFound
        }

        if isFileEncrypted(url) {
            return .encrypted
        } else {
            return .unencrypted
        }
    }

    /// Encrypt all unencrypted files in a directory
    func encryptAllFilesInDirectory(_ directoryURL: URL) throws -> (encrypted: Int, failed: Int) {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)

        var encryptedCount = 0
        var failedCount = 0

        for file in files where file.pathExtension == "wav" || file.pathExtension == "mp4" {
            do {
                try encryptFileInPlace(at: file)
                encryptedCount += 1
                print("✅ Encrypted: \(file.lastPathComponent)")
            } catch {
                failedCount += 1
                print("❌ Failed to encrypt \(file.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return (encryptedCount, failedCount)
    }

    /// Verify encryption integrity
    func verifyEncryptedFile(at encryptedURL: URL) throws -> Bool {
        do {
            _ = try decryptAudioFile(at: encryptedURL)
            return true
        } catch {
            return false
        }
    }

    /// Get file size (encrypted vs unencrypted)
    func getFileSizeInfo(_ url: URL) -> (sizeBytes: Int, sizeString: String) {
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return (0, "Unknown")
        }

        let sizeBytes = attributes[.size] as? Int ?? 0
        let sizeString = ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)

        return (sizeBytes, sizeString)
    }
}

// MARK: - Encryption Status

enum EncryptionStatus {
    case encrypted
    case unencrypted
    case notFound

    var displayName: String {
        switch self {
        case .encrypted:
            return "Encrypted"
        case .unencrypted:
            return "Unencrypted (needs encryption)"
        case .notFound:
            return "File not found"
        }
    }
}

// MARK: - Errors

enum EncryptionError: LocalizedError {
    case keyGenerationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidCiphertext
    case fileNotFound
    case fileOperationFailed(String)

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .encryptionFailed:
            return "Failed to encrypt file"
        case .decryptionFailed:
            return "Failed to decrypt file"
        case .invalidCiphertext:
            return "Invalid encrypted data - may be corrupted"
        case .fileNotFound:
            return "File not found"
        case .fileOperationFailed(let operation):
            return "File operation failed: \(operation)"
        }
    }
}
