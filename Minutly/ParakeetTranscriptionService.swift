//
//  ParakeetTranscriptionService.swift
//  Minutly
//
//  Local transcription with NVIDIA Parakeet TDT 0.6b v3 (CoreML, Apple Neural Engine).
//  No API key, no cloud upload. Model (~600 MB) downloads from HuggingFace on demand.
//
//  Parakeet has no speaker ID of its own. Speaker labels come from FluidAudio's
//  separate diarizer (pyannote segmentation + wespeaker embeddings, ~35 MB, also local):
//    - diarization splits the audio into "who spoke when" (Speaker 1, Speaker 2, ...)
//    - enrolled voice profiles turn those anonymous IDs into real names
//  Both run on-device; nothing about a voice ever leaves the Mac.
//

import Foundation
import Combine
import FluidAudio

/// Diarization is CPU-heavy and synchronous — an actor keeps it off the main thread.
actor SpeakerDiarizer {
    private var manager: DiarizerManager?

    private func loaded() async throws -> DiarizerManager {
        if let manager { return manager }
        let created = DiarizerManager()
        created.initialize(models: try await DiarizerModels.downloadIfNeeded())
        manager = created
        return created
    }

    /// Seeds the clustering with enrolled voices, so matching segments come back
    /// tagged with the person's name instead of an anonymous number.
    func segments(for samples: [Float], knownSpeakers: [Speaker]) async throws -> [TimedSpeakerSegment] {
        let manager = try await loaded()
        manager.initializeKnownSpeakers(knownSpeakers)
        return try manager.performCompleteDiarization(samples).segments
    }

}

/// An unidentified voice from one recording: where to hear it, and its voiceprint.
/// Written next to the transcript so the user can name it after the fact.
struct SpeakerSample: Codable, Identifiable {
    let speakerId: String
    let startTime: Double
    let endTime: Double
    let embedding: [Float]

    var id: String { speakerId }
}

/// Per-recording sidecar of not-yet-named voices, keyed off the audio file like the transcript is.
enum SpeakerSampleStore {
    static func fileURL(for audioURL: URL) -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let name = audioURL.deletingPathExtension().lastPathComponent
        return documents.appendingPathComponent("\(name)_speakers.json")
    }

    static func load(for audioURL: URL) -> [SpeakerSample] {
        guard let url = fileURL(for: audioURL), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([SpeakerSample].self, from: data)) ?? []
    }

    static func save(_ samples: [SpeakerSample], for audioURL: URL) {
        guard let url = fileURL(for: audioURL) else { return }
        if samples.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? JSONEncoder().encode(samples).write(to: url, options: .atomic)
    }

    static func delete(for audioURL: URL) {
        guard let url = fileURL(for: audioURL) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

/// Enrolled voices, persisted as JSON alongside the app's other state.
@MainActor
final class VoiceProfileStore: ObservableObject {
    static let shared = VoiceProfileStore()

    @Published private(set) var speakers: [Speaker] = []

    private let fileURL: URL

    init() {
        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupportPath.appendingPathComponent("com.minutly")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("voice_profiles.json")

        if let data = try? Data(contentsOf: fileURL) {
            speakers = (try? JSONDecoder().decode([Speaker].self, from: data)) ?? []
        }
    }

    /// Names a voice heard in a meeting. Reusing an existing name replaces that profile.
    @discardableResult
    func enroll(name: String, embedding: [Float]) throws -> Speaker {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VoiceProfileError.emptyName }

        let speaker = Speaker(id: trimmed, name: trimmed, currentEmbedding: embedding, isPermanent: true)
        speakers.removeAll { $0.id == trimmed }
        speakers.append(speaker)
        save()
        return speaker
    }

    func remove(_ speaker: Speaker) {
        speakers.removeAll { $0.id == speaker.id }
        save()
    }

    private func save() {
        do {
            try JSONEncoder().encode(speakers).write(to: fileURL, options: .atomic)
        } catch {
            print("❌ Failed to save voice profiles: \(error.localizedDescription)")
        }
    }
}

enum VoiceProfileError: LocalizedError {
    case emptyName

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Give the voice a name first."
        }
    }
}

@MainActor
final class ParakeetTranscriptionService: ObservableObject {
    static let shared = ParakeetTranscriptionService()

    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0

    private let diarizer = SpeakerDiarizer()

    /// ~/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3-coreml (inside the sandbox container)
    var modelDirectory: URL { AsrModels.defaultCacheDirectory(for: .v3) }

    var isDownloaded: Bool { AsrModels.modelsExist(at: modelDirectory) }

    var speakerIDEnabled: Bool {
        UserDefaults.standard.object(forKey: "parakeetSpeakerID") as? Bool ?? true
    }

    // ponytail: kept warm for the app's lifetime; ~2 GB resident. Add an idle-unload timer if memory complains.
    private var manager: AsrManager?

    /// Downloads the model if missing, then loads it. Safe to call repeatedly.
    @discardableResult
    func prepare() async throws -> AsrManager {
        if let manager { return manager }

        isDownloading = !isDownloaded
        defer { isDownloading = false }

        let models = try await AsrModels.downloadAndLoad(version: .v3) { [weak self] progress in
            Task { @MainActor in self?.downloadProgress = progress.fractionCompleted }
        }
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        self.manager = manager
        return manager
    }

    /// - Parameters:
    ///   - audioURL: the audio to transcribe (already decrypted).
    ///   - sidecarURL: the original recording, used to key the unnamed-speaker sidecar.
    func transcribe(audioURL: URL, sidecarURL: URL? = nil) async throws -> String {
        let manager = try await prepare()
        // Resample once and reuse for both ASR and diarization.
        let samples = try AudioConverter().resampleAudioFile(audioURL)

        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(samples, decoderState: &state)

        guard speakerIDEnabled, let timings = result.tokenTimings, !timings.isEmpty else {
            return result.text
        }
        // Diarization is best-effort: a plain transcript beats no transcript.
        do {
            let known = VoiceProfileStore.shared.speakers
            let segments = try await diarizer.segments(for: samples, knownSpeakers: known)
            if let sidecarURL {
                SpeakerSampleStore.save(Self.unnamedSamples(from: segments), for: sidecarURL)
            }
            return Self.label(buildWordTimings(from: timings), with: segments) ?? result.text
        } catch {
            print("⚠️ Diarization failed, returning unlabelled transcript: \(error.localizedDescription)")
            return result.text
        }
    }

    /// Picks one playable excerpt per voice that didn't match an enrolled profile.
    /// Longest segment wins — the most audio to judge by, and the least likely to be a stray "yeah".
    nonisolated static func unnamedSamples(from segments: [TimedSpeakerSegment]) -> [SpeakerSample] {
        var best: [String: TimedSpeakerSegment] = [:]
        for segment in segments where Int(segment.speakerId) != nil {
            if let existing = best[segment.speakerId], existing.durationSeconds >= segment.durationSeconds {
                continue
            }
            best[segment.speakerId] = segment
        }
        return best.values
            .sorted { $0.startTimeSeconds < $1.startTimeSeconds }
            .map {
                SpeakerSample(
                    speakerId: $0.speakerId,
                    startTime: Double($0.startTimeSeconds),
                    endTime: Double($0.endTimeSeconds),
                    embedding: $0.embedding
                )
            }
    }

    /// Assigns each word to the speaker segment covering its midpoint, then groups consecutive runs.
    // ponytail: naive O(words × segments) scan — ~5M compares for a 1h meeting, still under a millisecond.
    nonisolated static func label(_ words: [WordTiming], with segments: [TimedSpeakerSegment]) -> String? {
        guard !words.isEmpty, !segments.isEmpty else { return nil }

        // Unmatched voices get numeric IDs from the clustering; enrolled ones carry the person's name.
        // ponytail: someone enrolled as "007" would render as "Speaker 007". Store a UUID→name map if that ever bites.
        func display(_ id: String) -> String { Int(id) == nil ? id : "Speaker \(id)" }

        var lines: [String] = []
        var speaker: String?
        var buffer: [String] = []

        func flush() {
            guard let speaker, !buffer.isEmpty else { return }
            lines.append("\(display(speaker)): \(buffer.joined(separator: " "))")
        }

        for word in words {
            let mid = (word.startTime + word.endTime) / 2
            // Words landing in a gap between segments stay with the current speaker.
            let match = segments.first {
                Double($0.startTimeSeconds) <= mid && mid <= Double($0.endTimeSeconds)
            }?.speakerId ?? speaker ?? segments[0].speakerId

            if match != speaker {
                flush()
                speaker = match
                buffer = []
            }
            buffer.append(word.word)
        }
        flush()

        return lines.isEmpty ? nil : lines.joined(separator: "\n\n")
    }

    func deleteModel() throws {
        manager = nil
        try FileManager.default.removeItem(at: modelDirectory)
        objectWillChange.send()
    }
}
