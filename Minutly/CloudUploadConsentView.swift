//
//  CloudUploadConsentView.swift
//  Minutly
//
//  Created by Benjamin Patin on 08/12/2025.
//

import SwiftUI

struct CloudUploadConsentView: View {
    @Environment(\.dismiss) private var dismiss

    let recordingTitle: String
    let recordingDuration: TimeInterval
    let sensitivity: DataSensitivity
    let provider: String
    let onConsent: (Bool, String?) -> Void

    @State private var selectedReason: String = ""
    @State private var customReason: String = ""
    @State private var showCustomReasonField = false

    private let providerDisplayName: String

    init(
        recordingTitle: String,
        recordingDuration: TimeInterval,
        sensitivity: DataSensitivity,
        provider: String,
        onConsent: @escaping (Bool, String?) -> Void
    ) {
        self.recordingTitle = recordingTitle
        self.recordingDuration = recordingDuration
        self.sensitivity = sensitivity
        self.provider = provider
        self.onConsent = onConsent

        switch provider {
        case "openai":
            self.providerDisplayName = "OpenAI"
        case "assemblyai":
            self.providerDisplayName = "AssemblyAI"
        default:
            self.providerDisplayName = provider.uppercased()
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)

                    Text("Confirm Cloud Upload")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("This recording contains \(sensitivity.displayName) data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 8)

            Divider()

            // Recording Details
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Recording", value: recordingTitle)
                DetailRow(label: "Duration", value: formatDuration(recordingDuration))
                DetailRow(label: "Upload to", value: providerDisplayName)
                DetailRow(label: "Data Sensitivity", value: sensitivity.rawValue.capitalized)
            }
            .padding(12)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)

            // Warning
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Privacy Notice")
                        .fontWeight(.semibold)
                }

                Text("""
                By uploading this recording to \(providerDisplayName):
                • Your audio will be transmitted over HTTPS
                • \(providerDisplayName) may store your data according to their privacy policy
                • You have the right to request data deletion
                • This action cannot be undone
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

            // Reason Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Why are you uploading this recording?")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(consentReasons, id: \.self) { reason in
                        HStack {
                            Image(systemName: selectedReason == reason ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedReason == reason ? .blue : .gray)
                            Text(reason)
                                .font(.caption)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedReason = reason
                            showCustomReasonField = (reason == "Other")
                        }
                    }
                }
            }

            if showCustomReasonField {
                TextField("Please specify...", text: $customReason)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 12) {
                Button(role: .cancel) {
                    onConsent(false, nil)
                    dismiss()
                } label: {
                    Label("Decline", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    let reason = selectedReason == "Other" ? customReason : selectedReason
                    onConsent(true, reason)
                    dismiss()
                } label: {
                    Label("Upload Recording", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedReason.isEmpty || (showCustomReasonField && customReason.isEmpty))
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 600)
        .background(Color.white)
    }

    private var consentReasons: [String] {
        [
            "Accurate transcription needed",
            "Speaker identification required",
            "Business meeting record",
            "Research/educational purposes",
            "Other"
        ]
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, secs)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    CloudUploadConsentView(
        recordingTitle: "Team Standup",
        recordingDuration: 1234,
        sensitivity: .confidential,
        provider: "openai",
        onConsent: { _, _ in }
    )
}
