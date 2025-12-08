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
        if let keyData = try keychainService.retrieveAPIKey(for: keyIdentifier) {
            if let data = keyData.data(using: .utf8), data.count == 32 {
                return SymmetricKey(data: data)
            }
        }

        // Create a new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        // Store in Keychain
        try keychainService.saveAPIKey(keyData.base64EncodedString(), for: keyIdentifier)
        print("✅ Created and stored new encryption master key")

        return newKey
    }

    // MARK: - Encryption

    /// Encrypt audio data using AES-GCM
    func encryptAudioFile(at sourceURL: URL, to destinationURL: URL) throws {
        let audioData = try Data(contentsOf: sourceURL)
        let encryptedData = try encryptData(audioData)

        try encryptedData.write(to: destinationURL, options: .atomic)
        print("✅ Audio file encrypted: \(sourceURL.lastPathComponent)")
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

    /// Decrypt audio data using AES-GCM
    func decryptAudioFile(at encryptedURL: URL) throws -> Data {
        let encryptedData = try Data(contentsOf: encryptedURL)
        return try decryptData(encryptedData)
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
