//
//  LlamaModelManager.swift
//  Minutly
//
//  Created by Claude Code on 04/01/2025.
//  Manages Llama model download, storage, and device-specific selection
//

import Foundation
import CryptoKit

class LlamaModelManager: ObservableObject {
    static let shared = LlamaModelManager()

    enum ModelVariant: String {
        case llama1B = "llama-3.2-1b-instruct-q4_k_m"  // Intel Macs, older devices
        case llama3B = "llama-3.2-3b-instruct-q4_k_m"  // Apple Silicon

        var displayName: String {
            switch self {
            case .llama1B: return "Llama 3.2 1B"
            case .llama3B: return "Llama 3.2 3B"
            }
        }

        var fileSize: Int64 {
            switch self {
            case .llama1B: return 800_000_000  // ~800 MB
            case .llama3B: return 2_000_000_000  // ~2 GB
            }
        }

        var downloadURL: String {
            switch self {
            case .llama1B:
                return "https://huggingface.co/TheBloke/Llama-3.2-1B-Instruct-GGUF/resolve/main/llama-3.2-1b-instruct.Q4_K_M.gguf"
            case .llama3B:
                return "https://huggingface.co/TheBloke/Llama-3.2-3B-Instruct-GGUF/resolve/main/llama-3.2-3b-instruct.Q4_K_M.gguf"
            }
        }

        var fileName: String {
            return "\(self.rawValue).gguf"
        }
    }

    enum LlamaError: LocalizedError {
        case insufficientDiskSpace(required: Int64, available: Int64)
        case downloadFailed(String)
        case modelNotFound
        case modelCorrupted
        case checksumMismatch
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .insufficientDiskSpace(let required, let available):
                let requiredGB = Double(required) / 1_000_000_000
                let availableGB = Double(available) / 1_000_000_000
                return String(format: "Insufficient disk space. Required: %.1f GB, Available: %.1f GB", requiredGB, availableGB)
            case .downloadFailed(let message):
                return "Model download failed: \(message)"
            case .modelNotFound:
                return "Model file not found. Please download the model first."
            case .modelCorrupted:
                return "Model file is corrupted. Please re-download."
            case .checksumMismatch:
                return "Model file checksum doesn't match. File may be corrupted."
            case .networkError(let message):
                return "Network error: \(message)"
            }
        }
    }

    // MARK: - Published Properties

    @Published var downloadProgress: Double = 0.0
    @Published var downloadSpeed: String = ""
    @Published var isDownloading: Bool = false
    @Published var currentModel: ModelVariant?

    // MARK: - Private Properties

    private var downloadTask: URLSessionDownloadTask?
    private var observation: NSKeyValueObservation?

    private init() {
        detectCurrentModel()
    }

    // MARK: - Device Detection

    /// Detect the appropriate model based on chip architecture
    func selectModelForDevice() -> ModelVariant {
        #if arch(arm64)
        // Apple Silicon (M1/M2/M3)
        return .llama3B
        #else
        // Intel Macs
        return .llama1B
        #endif
    }

    /// Check if device is Intel Mac
    var isIntelMac: Bool {
        #if arch(arm64)
        return false
        #else
        return true
        #endif
    }

    // MARK: - Model Path Management

    /// Get the directory where models are stored
    private func getModelsDirectory() throws -> URL {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(for: .applicationSupportDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil,
                                              create: true)

        let modelsDir = appSupport.appendingPathComponent("Minutly/Models", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: modelsDir.path) {
            try fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }

        return modelsDir
    }

    /// Get the file path for a specific model variant
    func getModelPath(for variant: ModelVariant? = nil) throws -> URL {
        let modelVariant = variant ?? selectModelForDevice()
        let modelsDir = try getModelsDirectory()
        return modelsDir.appendingPathComponent(modelVariant.fileName)
    }

    // MARK: - Model Status

    /// Check if a specific model is downloaded
    func isModelDownloaded(_ variant: ModelVariant? = nil) -> Bool {
        do {
            let modelPath = try getModelPath(for: variant)
            return FileManager.default.fileExists(atPath: modelPath.path)
        } catch {
            print("❌ Error checking model: \(error.localizedDescription)")
            return false
        }
    }

    /// Detect which model (if any) is currently downloaded
    private func detectCurrentModel() {
        if isModelDownloaded(.llama3B) {
            currentModel = .llama3B
        } else if isModelDownloaded(.llama1B) {
            currentModel = .llama1B
        } else {
            currentModel = nil
        }
    }

    // MARK: - Disk Space Check

    /// Check if there's sufficient disk space for the model
    private func hasSufficientDiskSpace(for variant: ModelVariant) throws -> Bool {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: false)

        let attributes = try fileManager.attributesOfFileSystem(forPath: appSupportURL.path)
        guard let freeSize = attributes[.systemFreeSize] as? Int64 else {
            return false
        }

        // Require 1.5x the model size to be safe
        let requiredSpace = Int64(Double(variant.fileSize) * 1.5)

        if freeSize < requiredSpace {
            throw LlamaError.insufficientDiskSpace(required: requiredSpace, available: freeSize)
        }

        return true
    }

    // MARK: - Model Download

    /// Download the model if not already present
    func downloadModel(_ variant: ModelVariant? = nil) async throws {
        let modelVariant = variant ?? selectModelForDevice()

        // Check if already downloaded
        if isModelDownloaded(modelVariant) {
            print("✅ Model \(modelVariant.displayName) already downloaded")
            currentModel = modelVariant
            return
        }

        // Check disk space
        _ = try hasSufficientDiskSpace(for: modelVariant)

        print("📥 Starting download of \(modelVariant.displayName) (\(modelVariant.fileSize / 1_000_000) MB)")

        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
        }

        do {
            try await performDownload(modelVariant)

            await MainActor.run {
                isDownloading = false
                downloadProgress = 1.0
                currentModel = modelVariant
            }

            print("✅ Model downloaded successfully: \(modelVariant.displayName)")
        } catch {
            await MainActor.run {
                isDownloading = false
                downloadProgress = 0.0
            }
            throw LlamaError.downloadFailed(error.localizedDescription)
        }
    }

    /// Perform the actual download with progress tracking
    private func performDownload(_ variant: ModelVariant) async throws {
        guard let url = URL(string: variant.downloadURL) else {
            throw LlamaError.downloadFailed("Invalid URL")
        }

        let destinationURL = try getModelPath(for: variant)

        // Configure URLSession for downloads
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300  // 5 minutes timeout
        configuration.timeoutIntervalForResource = 3600  // 1 hour for large files

        let session = URLSession(configuration: configuration,
                                 delegate: nil,
                                 delegateQueue: nil)

        // Download the file
        let (tempURL, response) = try await session.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LlamaError.networkError("Invalid response from server")
        }

        // Move to final destination
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: tempURL, to: destinationURL)

        print("✅ File saved to: \(destinationURL.path)")
    }

    /// Cancel ongoing download
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil

        DispatchQueue.main.async {
            self.isDownloading = false
            self.downloadProgress = 0.0
        }

        print("⚠️ Download cancelled")
    }

    // MARK: - Model Deletion

    /// Delete a specific model variant
    func deleteModel(_ variant: ModelVariant? = nil) throws {
        let modelVariant = variant ?? selectModelForDevice()
        let modelPath = try getModelPath(for: modelVariant)

        if FileManager.default.fileExists(atPath: modelPath.path) {
            try FileManager.default.removeItem(at: modelPath)
            print("✅ Deleted model: \(modelVariant.displayName)")

            if currentModel == modelVariant {
                currentModel = nil
            }
        }
    }

    /// Delete all models
    func deleteAllModels() throws {
        let modelsDir = try getModelsDirectory()
        if FileManager.default.fileExists(atPath: modelsDir.path) {
            try FileManager.default.removeItem(at: modelsDir)
            currentModel = nil
            print("✅ All models deleted")
        }
    }

    // MARK: - Model Info

    /// Get the size of a downloaded model in bytes
    func getModelSize(_ variant: ModelVariant? = nil) -> Int64? {
        do {
            let modelPath = try getModelPath(for: variant)
            let attributes = try FileManager.default.attributesOfItem(atPath: modelPath.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }

    /// Format bytes to human-readable string
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
