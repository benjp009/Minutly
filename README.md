# Minutly

<div align="center">

**Intelligent Audio Recording & Transcription for macOS**

A native macOS application for recording, transcribing, and summarizing meetings and conversations with automatic detection, secure encryption, and AI-powered insights.

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [Security](#security) • [Development](#development)

</div>

---

## Overview

Minutly is a privacy-focused macOS app built with SwiftUI that captures audio conversations, provides accurate transcriptions with multiple provider options, and generates AI-powered summaries with action items and key insights.

### Key Highlights

- **Smart Recording** - Pre-buffering captures 30 seconds before you hit record
- **Multiple Transcription Options** - Choose from Apple Speech (free), AssemblyAI (speaker ID), or OpenAI Whisper
- **Meeting Detection** - Automatic calendar integration with 2-minute advance notifications
- **AI Summaries** - GPT-powered conversation summaries with action items and participant insights
- **Privacy First** - AES-256-GCM encryption for all recordings, secure keychain storage, no telemetry
- **Menu Bar Mode** - Quick access recording controls without cluttering your dock

---

## Features

### Audio Recording

- **Pre-buffering** - Captures 30 seconds of audio before recording starts
- **Background Recording** - Continue recording while using other apps
- **Encrypted Storage** - All recordings encrypted at rest with AES-256-GCM
- **Waveform Visualization** - Real-time audio visualization during playback
- **High-Quality Audio** - Professional-grade audio capture using AVFoundation

### Transcription Services

**Apple Speech Recognition**
- Free and offline
- 50+ languages supported
- No speaker identification
- Instant processing

**AssemblyAI**
- Speaker diarization (identifies who said what)
- 99+ languages supported
- High accuracy enterprise-grade transcription
- Requires API key

**OpenAI Whisper**
- State-of-the-art accuracy
- Multilingual support with translation
- Punctuation and formatting
- Requires API key

### AI-Powered Summaries

- **Conversation Overview** - Key topics and themes discussed
- **Action Items** - Automatically extracted tasks and next steps
- **Participant Insights** - Contribution analysis for each speaker
- **Key Points** - Most important takeaways highlighted
- **Cost-Effective** - ~$0.001-0.002 per summary using GPT-3.5

### Meeting Detection

- Monitors macOS Calendar for upcoming meetings
- Sends notifications 2 minutes before meetings start
- One-tap recording with automatic pre-buffering
- Configurable per-meeting consent flow

### Security & Privacy

- **End-to-End Encryption** - AES-256-GCM encryption for all recordings
- **Secure Keychain Storage** - API keys and encryption keys stored securely
- **Certificate Pinning** - Protected API communications
- **Audit Logging** - Security event tracking
- **No Telemetry** - Zero analytics or tracking
- **Local-First** - All processing happens on your device when possible

---

## Installation

### Requirements

- macOS 13.0 (Ventura) or later
- Microphone permissions
- Optional: Calendar permissions for meeting detection
- Optional: API keys for cloud transcription services

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/minutly.git
cd minutly
```

2. Open in Xcode:
```bash
open Minutly.xcodeproj
```

3. Build and run (⌘R)

### First Launch

On first launch, Minutly will guide you through:
1. Microphone permissions setup
2. Transcription service selection
3. Optional: API key configuration for cloud services
4. Optional: Meeting detection setup

---

## Usage

### Recording Audio

1. **Manual Recording**
   - Click the record button in the main window or menu bar
   - Optionally enable pre-buffering to capture 30 seconds before recording starts
   - Click stop when finished

2. **Meeting Detection**
   - Enable in Settings → Meeting Detection
   - Grant Calendar permissions
   - Receive notifications 2 minutes before meetings
   - Confirm to start recording with pre-buffering

### Transcription

1. Select a recording from the list
2. Choose your transcription provider:
   - **Apple Speech** - Instant, free, no setup required
   - **AssemblyAI** - Add API key in Settings for speaker identification
   - **OpenAI Whisper** - Add API key in Settings for highest accuracy
3. Click "Transcribe" and wait for processing

### AI Summaries

After transcription completes:
1. Click "Generate Summary" on any transcribed recording
2. Requires OpenAI API key (set in Settings)
3. View summary with:
   - Conversation overview
   - Action items
   - Key points
   - Participant insights

### Menu Bar Mode

Enable in Settings → Menu Bar Mode for quick access:
- Quick record/stop controls
- Recording status indicator
- Access to recent recordings
- Settings shortcut

---

## Configuration

### Settings (⌘,)

**Transcription Provider**
- Choose default service: Apple Speech, AssemblyAI, or OpenAI Whisper

**API Keys** (Secure Keychain Storage)
- AssemblyAI API Key
- OpenAI API Key

**Meeting Detection**
- Enable/disable calendar integration
- Configure notification preferences

**Privacy & Security**
- View audit logs
- Manage encryption keys
- Reset onboarding

**Appearance**
- Menu bar mode toggle
- Recording preferences

---

## Security

Minutly is designed with privacy and security as top priorities:

### Encryption

- **Algorithm**: AES-256-GCM (NIST-approved)
- **Key Storage**: macOS Keychain (encrypted at rest)
- **Scope**: All recordings encrypted before saving to disk
- **Implementation**: CryptoKit framework

### API Security

- **Certificate Pinning**: Prevents man-in-the-middle attacks
- **Secure Key Storage**: API keys stored in Keychain, never in UserDefaults or files
- **Audit Logging**: All security events logged for review

### Privacy Guarantees

- **No Telemetry**: Zero analytics or tracking
- **No Cloud Storage**: Recordings stored locally unless explicitly uploaded
- **User Control**: Explicit consent required for all cloud operations
- **Data Minimization**: Only necessary data sent to transcription services

### Security Best Practices

1. Never log sensitive data (API keys, user content)
2. Encrypt all recordings before disk write
3. Use certificate pinning for external APIs
4. Audit log security-relevant events
5. Validate all user inputs

---

## Development

### Project Structure

```
Minutly/
├── MinutlyApp.swift              # App entry point
├── ContentView.swift             # Main interface
├── SettingsView.swift            # Settings UI
├── RecordingRow.swift            # Recording list item
├── SummaryView.swift             # AI summary display
│
├── Recording & Audio/
│   ├── ScreenRecorder.swift      # Core recording engine
│   ├── WaveformView.swift        # Audio visualization
│   └── RecordingMetadata.swift   # Data models
│
├── Transcription/
│   ├── TranscriptionService.swift        # Protocol
│   ├── AppleSpeechRecognizer.swift       # Apple Speech
│   ├── AssemblyAIService.swift           # AssemblyAI
│   └── OpenAITranscriptionService.swift  # Whisper
│
├── Security/
│   ├── EncryptionService.swift           # AES-256-GCM
│   ├── KeychainService.swift             # Secure storage
│   ├── CertificatePinningDelegate.swift  # API security
│   └── AuditLogger.swift                 # Event logging
│
├── Meeting Detection/
│   ├── MeetingConfirmationManager.swift
│   └── CloudUploadConsentView.swift
│
└── Onboarding/
    ├── OnboardingContainerView.swift
    └── [Additional onboarding views]
```

### Technology Stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI
- **Platform**: macOS 13.0+ (Ventura)
- **Audio**: AVFoundation
- **Encryption**: CryptoKit (AES-256-GCM)
- **Dependencies**: Native frameworks only (no third-party packages)

### Semantic Code Search

This project uses **mgrep** for intelligent code exploration:

```bash
# Install mgrep
npm install -g @mixedbread/mgrep
export MXBAI_API_KEY=your_api_key_here

# Index the repository
cd /path/to/Minutly
mgrep watch

# Example semantic queries
mgrep "where are API keys stored?"
mgrep "trace the recording lifecycle"
mgrep "find all encryption operations"
```

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme Minutly -destination 'platform=macOS'

# Run specific test suite
xcodebuild test -scheme Minutly -destination 'platform=macOS' \
  -only-testing:MinutlyTests/RegressionTests
```

See [REGRESSION_TESTS.md](REGRESSION_TESTS.md) for detailed test documentation.

### Development Guidelines

1. **Read Before Modifying** - Always read existing files to understand patterns
2. **Follow SwiftUI Conventions** - Use declarative UI patterns
3. **Maintain Security Standards** - Never compromise encryption/privacy
4. **Test Thoroughly** - Run regression tests before committing
5. **Keep It Simple** - Avoid over-engineering, focus on user needs

### Code Style

- Use `@State` for view-local state
- Use `@AppStorage` for UserDefaults persistence
- Use `@EnvironmentObject` for shared app state
- All async operations use Swift concurrency (`async`/`await`)
- Error handling with `do-catch` and user-friendly messages
- Emoji logging convention (✅ success, ❌ error, ⚠️ warning)

---

## API Keys

### AssemblyAI

Sign up at [assemblyai.com](https://www.assemblyai.com/) for transcription with speaker diarization.

### OpenAI

Get your API key at [platform.openai.com](https://platform.openai.com/) for:
- Whisper transcription (high accuracy)
- GPT-3.5 summaries (action items, insights)

**Cost Estimates:**
- Whisper: ~$0.006 per minute of audio
- GPT-3.5 Summary: ~$0.001-0.002 per transcript

---

## Documentation

- [CLAUDE.md](CLAUDE.md) - Complete project documentation and architecture
- [REGRESSION_TESTS.md](REGRESSION_TESTS.md) - Regression test suite
- [TEST_SETUP_GUIDE.md](TEST_SETUP_GUIDE.md) - Test environment setup
- [TESTING_QUICK_REFERENCE.md](TESTING_QUICK_REFERENCE.md) - Quick testing commands

---

## Roadmap

- [ ] Export recordings to multiple formats (MP3, WAV, M4A)
- [ ] Custom AI summary templates
- [ ] Batch transcription processing
- [ ] Cloud backup integration (optional)
- [ ] iOS companion app
- [ ] Real-time transcription display
- [ ] Advanced search across transcripts

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Follow the development guidelines in [CLAUDE.md](CLAUDE.md)
4. Run tests before committing
5. Submit a pull request

---

## License

[Add your license here - e.g., MIT, GPL, proprietary]

---

## Support

For issues, questions, or feature requests:
- Open an issue on GitHub
- Check [CLAUDE.md](CLAUDE.md) for detailed documentation
- Review [REGRESSION_TESTS.md](REGRESSION_TESTS.md) for testing help

---

## Acknowledgments

- Built with SwiftUI and Swift Concurrency
- Powered by AssemblyAI, OpenAI, and Apple Speech Recognition
- Inspired by the need for privacy-focused meeting tools

---

<div align="center">

**Made with ❤️ for privacy-conscious professionals**

</div>
