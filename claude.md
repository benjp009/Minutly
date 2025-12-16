# Minutly - macOS Audio Recording & Transcription App

## Project Overview

Minutly is a native macOS application built with SwiftUI that provides intelligent audio recording, transcription, and summarization capabilities. The app is designed for meetings and conversations with automatic detection, secure encryption, and flexible transcription options.

## Architecture

### Core Components

- **MinutlyApp.swift** - Main app entry point with onboarding flow and menu bar mode support
- **AppState** - Manages global app state and coordinates between components
- **ScreenRecorder** - Handles audio recording with pre-buffering capabilities
- **MenuBarController** - Manages menu bar presence and quick actions

### Key Features

1. **Audio Recording**
   - Pre-buffering support (captures 30 seconds before recording starts)
   - Encrypted storage using AES-256-GCM
   - Background recording capability

2. **Transcription Services** (3 providers)
   - Apple Speech Recognition (free, offline, no speaker ID)
   - AssemblyAI (paid, speaker diarization, 99+ languages)
   - OpenAI Whisper (paid, high accuracy)

3. **Meeting Detection**
   - Monitors macOS Calendar for upcoming meetings
   - Sends notifications 2 minutes before meetings
   - Auto-starts pre-buffering when confirmed

4. **AI Summarization**
   - Uses OpenAI GPT-3.5 for conversation summaries
   - Generates action items, key points, and participant insights
   - Cost-effective (~$0.001-0.002 per summary)

5. **Security & Privacy**
   - End-to-end encryption for all recordings
   - Secure keychain storage for API keys and encryption keys
   - Certificate pinning for API communications
   - Audit logging for security events

## Project Structure

```
Minutly/
├── MinutlyApp.swift                    # App entry point
├── SettingsView.swift                  # Settings UI (API keys, preferences)
├── ContentView.swift                   # Main app interface
├── RecordingRow.swift                  # Recording list item with playback
├── SummaryView.swift                   # AI summary display
│
├── Recording & Audio
│   ├── ScreenRecorder                  # Core recording engine
│   ├── WaveformView.swift              # Audio visualization
│   └── RecordingMetadata.swift         # Recording data model
│
├── Transcription
│   ├── TranscriptionService            # Base protocol
│   ├── AppleSpeechRecognizer.swift     # Apple Speech implementation
│   ├── AssemblyAIService.swift         # AssemblyAI implementation
│   └── OpenAITranscriptionService.swift # Whisper implementation
│
├── Security
│   ├── EncryptionService.swift         # AES-256-GCM encryption
│   ├── KeychainService.swift           # Secure credential storage
│   ├── CertificatePinningDelegate.swift # API security
│   └── AuditLogger.swift               # Security event logging
│
├── Meeting Detection
│   ├── MeetingConfirmationManager.swift # Calendar integration
│   └── CloudUploadConsentView.swift    # User consent flow
│
└── Onboarding
    ├── OnboardingContainerView.swift
    ├── OnboardingNotificationLaunchView.swift
    ├── OnboardingTranscriptionConfirmView.swift
    └── OnboardingSummarizationSetupView.swift
```

## Technology Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Platform**: macOS 13.0+ (Ventura)
- **Audio**: AVFoundation
- **Encryption**: CryptoKit (AES-256-GCM)
- **API Integrations**:
  - AssemblyAI (transcription)
  - OpenAI (Whisper + GPT-3.5)
  - Apple Speech Recognition

## Key File Locations

### Settings & Configuration
- [SettingsView.swift](Minutly/SettingsView.swift) - All app settings and API configuration
- `.claude/settings.local.json` - Claude Code local settings

### Recording Management
- [RecordingRow.swift](Minutly/RecordingRow.swift) - Individual recording UI with playback
- [RecordingMetadata.swift](Minutly/RecordingMetadata.swift) - Recording data structure

### Security
- [KeychainService.swift](Minutly/KeychainService.swift) - API key and encryption key storage
- [EncryptionService.swift](Minutly/EncryptionService.swift) - File encryption/decryption
- [AuditLogger.swift](Minutly/AuditLogger.swift) - Security event tracking

### Testing
- [REGRESSION_TESTS.md](REGRESSION_TESTS.md) - Regression test documentation
- [TEST_SETUP_GUIDE.md](TEST_SETUP_GUIDE.md) - Test environment setup
- [TESTING_QUICK_REFERENCE.md](TESTING_QUICK_REFERENCE.md) - Quick testing commands

## Development Guidelines

### Code Style

1. **SwiftUI Best Practices**
   - Use `@State` for view-local state
   - Use `@AppStorage` for UserDefaults persistence
   - Use `@EnvironmentObject` for shared app state
   - Keep views focused and composable

2. **Async/Await**
   - All async operations use Swift concurrency
   - Mark async functions with `async throws` where appropriate
   - Use `@MainActor` for UI updates

3. **Error Handling**
   - Use `do-catch` blocks for recoverable errors
   - Log errors with appropriate emoji prefixes (❌, ⚠️, ✅)
   - Show user-friendly error messages in UI

### Security Practices

1. **Never log sensitive data** (API keys, encryption keys, user content)
2. **Always encrypt recordings** before saving to disk
3. **Store API keys in Keychain** using KeychainService
4. **Use certificate pinning** for external API calls
5. **Audit log security events** using AuditLogger

### Common Tasks

#### Adding a New Transcription Provider

1. Create new service class conforming to `TranscriptionService`
2. Add provider option to [SettingsView.swift](Minutly/SettingsView.swift) picker
3. Update API key storage in KeychainService
4. Add provider-specific UI in settings sections

#### Modifying Recording Behavior

1. Core logic is in `ScreenRecorder` class
2. Pre-buffering logic uses circular buffer pattern
3. Encryption happens automatically via EncryptionService
4. Update MenuBarController for status indicators

#### Updating Onboarding Flow

1. Modify views in Onboarding folder
2. Track progress with `currentOnboardingPage` in UserDefaults
3. Set `onboardingCompleted` flag when done
4. Reset available in [SettingsView.swift](Minutly/SettingsView.swift)

## Testing

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme Minutly -destination 'platform=macOS'

# Run specific test
xcodebuild test -scheme Minutly -destination 'platform=macOS' \
  -only-testing:MinutlyTests/RegressionTests/testRecordingSuccess
```

### Critical Test Coverage

- **Recording Success** - Validates recording creation and encryption
- **Playback Success** - Validates decryption and playback
- **Encryption Key Validity** - Validates key persistence

See [REGRESSION_TESTS.md](REGRESSION_TESTS.md) for detailed test documentation.

## User Defaults Keys

- `transcriptionProvider` - Selected provider ("apple", "assemblyai", "openai")
- `enableMeetingDetection` - Calendar integration toggle
- `enableMenuBarMode` - Menu bar vs dock mode
- `onboardingCompleted` - First-run setup completion
- `currentOnboardingPage` - Onboarding progress tracker

## API Keys & Credentials

All API keys are stored securely in macOS Keychain via KeychainService:

- `assemblyai` - AssemblyAI API key
- `openai` - OpenAI API key
- `encryption_key` - Master encryption key for recordings

Access via:
```swift
try KeychainService.shared.retrieveAPIKey(for: "assemblyai")
try KeychainService.shared.saveAPIKey(key, for: "openai")
```

## Common Issues & Solutions

### Recording Issues
- Check microphone permissions in System Settings
- Verify ScreenRecorder initialization
- Check encryption key availability in Keychain

### Transcription Failures
- Verify API keys are set in Settings
- Check internet connection for cloud providers
- Validate file format compatibility

### Menu Bar Not Showing
- Restart app after enabling menu bar mode
- Check `enableMenuBarMode` UserDefaults value
- Verify MenuBarController setup in MinutlyApp

## Build Configuration

- **Minimum macOS Version**: 13.0 (Ventura)
- **Swift Version**: 5.9+
- **Xcode Project**: `Minutly.xcodeproj`
- **App Identifier**: `Ugitech.Minutly`

## External Dependencies

The app uses native frameworks only:
- SwiftUI (UI)
- AVFoundation (Audio)
- CryptoKit (Encryption)
- EventKit (Calendar)
- Security (Keychain)

No third-party package dependencies required.

## Git Workflow

- **Main Branch**: Production-ready code
- **Current Branch**: `dev-branch` (active development)

### Recent Changes
- Onboarding flow improvements
- Security and performance review
- Critical bug fixes (deadlocks, memory leaks)
- Pre-buffer race condition fixes

## Contributing Guidelines

When making changes:

1. **Read relevant files first** - Understand existing patterns
2. **Follow SwiftUI conventions** - Use declarative UI patterns
3. **Maintain security standards** - Never compromise encryption/privacy
4. **Test thoroughly** - Run regression tests before committing
5. **Update documentation** - Keep this file and code comments current
6. **Avoid over-engineering** - Keep solutions simple and focused

## Performance Considerations

- **Memory**: Pre-buffer uses circular buffer to prevent memory exhaustion
- **CPU**: Transcription runs in background to avoid UI blocking
- **Disk**: Encrypted files are compressed efficiently
- **Network**: API calls use certificate pinning and retry logic

## Accessibility

- VoiceOver labels on interactive elements
- Keyboard shortcuts for common actions (⌘, for Settings)
- Clear visual indicators for recording state

## Privacy & Compliance

- All recordings encrypted at rest
- No telemetry or analytics tracking
- User controls all cloud uploads
- Transparent API usage in settings
- Audit logging for security events

---

**Last Updated**: 2025-12-16
**Project Version**: Active Development
**Documentation Status**: Complete
