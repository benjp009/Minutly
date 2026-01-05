//
//  ModelDownloadView.swift
//  Minutly
//
//  Created by Claude Code on 04/01/2025.
//  UI for downloading Llama AI models
//

import SwiftUI

struct ModelDownloadView: View {
    @ObservedObject var modelManager: LlamaModelManager
    @State private var isDownloading = false
    @State private var downloadError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("AI Model Download")
                .font(.title)
                .fontWeight(.bold)

            // Icon
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            // Description
            VStack(alignment: .leading, spacing: 12) {
                Text("First-Time Setup")
                    .font(.headline)

                Text("Minutly uses a local AI model for offline summarization. No internet connection required after download.")
                    .font(.body)
                    .foregroundColor(.secondary)

                // Model info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(modelManager.selectModelForDevice().displayName)
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Size:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(modelManager.formatBytes(modelManager.selectModelForDevice().fileSize))
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                // Device info
                if modelManager.isIntelMac {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Optimized for Intel Mac - Using smaller, faster model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()

            // Progress section
            if isDownloading || modelManager.isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: modelManager.downloadProgress)
                        .progressViewStyle(.linear)

                    HStack {
                        Text("\(Int(modelManager.downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if !modelManager.downloadSpeed.isEmpty {
                            Text(modelManager.downloadSpeed)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Downloading... This may take a few minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            // Error message
            if let error = downloadError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            Spacer()

            // Buttons
            HStack(spacing: 12) {
                // Cancel button (only during download)
                if isDownloading || modelManager.isDownloading {
                    Button(action: {
                        modelManager.cancelDownload()
                        isDownloading = false
                    }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                }

                // Skip button (only before download)
                if !isDownloading && !modelManager.isDownloading {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Skip for Now")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                }

                // Download button
                Button(action: {
                    startDownload()
                }) {
                    Text(isDownloading || modelManager.isDownloading ? "Downloading..." : "Download Model")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDownloading || modelManager.isDownloading)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 500, height: 450)
    }

    private func startDownload() {
        isDownloading = true
        downloadError = nil

        Task {
            do {
                try await modelManager.downloadModel()
                isDownloading = false

                // Auto-dismiss after successful download
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    downloadError = error.localizedDescription
                }
            }
        }
    }
}

struct ModelDownloadView_Previews: PreviewProvider {
    static var previews: some View {
        ModelDownloadView(modelManager: LlamaModelManager.shared)
    }
}
