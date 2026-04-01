# Minutly - macOS Audio Recording & Transcription App

## Project Overview

Minutly is a native macOS application built with SwiftUI that provides intelligent audio recording, transcription, and summarization capabilities. The app is designed for meetings and conversations with automatic detection, secure encryption, and flexible transcription options.

## Architecture

### Core Components

- **MinutlyApp.swift** - Main app entry point with splash screen and menu bar support
- **AppState** - Manages global app state and coordinates between components
- **OnboardingState** - ObservableObject managing onboarding flow, API key validation, and Keychain persistence
- **ScreenRecorder** - Handles audio recording with pre-buffering capabilities
- **MenuBarController** - Manages menu bar presence and quick actions

### Key Features

1. **Audio Recording**
   - Pre-buffering support (captures 30 seconds before recording starts)
   - Encrypted storage using AES-256-GCM
   - Background recording capability

2. **Transcription Services** (3 providers)
   - Apple Speech Recognition (free, offline, no speaker ID) - built into TranscriptionService.swift
   - AssemblyAI (paid, speaker diarization, 99+ languages) - via AssemblyAIService.swift
   - OpenAI Whisper (paid, high accuracy) - via OpenAITranscriptionService.swift
   - Provider selected via `transcriptionProvider` UserDefaults key

3. **AI Summarization**
   - Uses OpenAI GPT-3.5 via OpenAISummarizationService.swift
   - 4 built-in prompt templates (keypoints/tasks, executive, technical, sales) via SummaryPromptTemplates.swift
   - Custom prompt support (simple instructions or advanced prompt editor)
   - Cost-effective (~$0.001-0.002 per summary)

4. **Meeting Detection**
   - CalendarMonitorService: polls EventKit every 30 seconds for upcoming meetings, sends UNUserNotification alerts
   - MeetingConfirmationManager: records user consent/decline per meeting, persists to disk with 24-hour expiry
   - Auto-starts pre-buffering when confirmed

5. **Plan Selection**
   - 3 subscription tiers: Free (0 EUR), Be in Control (9 EUR/month, BYOK), All In (18 EUR/month, managed keys)
   - PlanType enum defines feature gates between tiers
   - Currently accessible via PlanSelectionView.swift

6. **Security & Privacy**
   - AES-256-GCM encryption for audio recordings
   - Secure keychain storage for API keys and encryption keys (kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
   - CertificatePinningDelegate infrastructure (currently initialized with empty pinnedDomains)
   - Audit logging for security events
   - CloudDataDeletionService for GDPR-style deletion requests against AssemblyAI + audit trail
   - **Note**: Transcription text files and summary JSON files are stored as plaintext (not encrypted)

## Project Structure

```
Minutly/
├── MinutlyApp.swift                    # App entry point + AppState
├── ContentView.swift                   # Main app interface
├── SettingsView.swift                  # Settings UI (API keys, preferences)
├── SplashScreenView.swift              # Animated 2-second launch screen
├── PlanSelectionView.swift             # Subscription tier selection (Free/Control/All In)
│
├── Recording & Audio
│   ├── ScreenRecorder.swift            # Core recording engine
│   ├── AudioPlayerView.swift           # Modal playback with progress + waveform
│   ├── WaveformView.swift              # Audio visualization
│   ├── RecordingRow.swift              # Recording list item UI
│   └── RecordingMetadata.swift         # Recording data model
│
├── Transcription & Summarization
│   ├── TranscriptionService.swift      # Concrete coordinator class (routes to providers, manages persistence)
│   ├── AssemblyAIService.swift         # AssemblyAI transcription client
│   ├── OpenAITranscriptionService.swift # OpenAI Whisper transcription client
│   ├── OpenAISummarizationService.swift # GPT-3.5 summarization + ConversationSummary model
│   ├── SummaryPromptTemplates.swift    # 4 built-in prompt templates + custom wrapper
│   └── SummaryView.swift              # AI summary display
│
├── Security
│   ├── EncryptionService.swift         # AES-256-GCM encryption
│   ├── KeychainService.swift           # Secure credential storage
│   ├── CertificatePinningDelegate.swift # API security delegate
│   ├── AuditLogger.swift               # Security event logging
│   └── CloudDataDeletionService.swift  # GDPR deletion requests + audit trail
│
├── Meeting Detection
│   ├── CalendarMonitorService.swift    # EventKit polling + notification delivery (primary engine)
│   ├── MeetingConfirmationManager.swift # User consent persistence + audit
│   └── CloudUploadConsentView.swift    # User consent flow UI
│
└── Onboarding (currently disabled - see note below)
    ├── OnboardingContainerView.swift   # 3-page container
    ├── OnboardingState.swift           # State machine + API key management
    ├── OnboardingTranscriptionSetupView.swift  # Page 1: AssemblyAI key entry
    ├── OnboardingSummarizationSetupView.swift  # Page 2: OpenAI key entry
    └── OnboardingPermissionsView.swift         # Page 3: Screen recording + notifications
```

> **Onboarding is currently disabled** via `if false` at MinutlyApp.swift:65. The app shows SplashScreenView for 2 seconds then goes directly to ContentView. Re-enable the condition to test the onboarding flow.

## Technology Stack

- **Language**: Swift 5.0+
- **UI Framework**: SwiftUI
- **Platform**: macOS 15.7+ (Sequoia)
- **Audio**: AVFoundation, Speech (SFSpeechRecognizer)
- **Encryption**: CryptoKit (AES-256-GCM)
- **API Integrations**:
  - AssemblyAI (transcription with speaker ID)
  - OpenAI (Whisper transcription + GPT-3.5 summarization)
  - Apple Speech Recognition (free, on-device/cloud)

## Key File Locations

### Settings & Configuration
- [SettingsView.swift](Minutly/SettingsView.swift) - All app settings and API configuration

### Recording Management
- [RecordingRow.swift](Minutly/RecordingRow.swift) - Individual recording UI with playback
- [RecordingMetadata.swift](Minutly/RecordingMetadata.swift) - Recording data structure
- [AudioPlayerView.swift](Minutly/AudioPlayerView.swift) - Modal playback view

### Security & Privacy
- [KeychainService.swift](Minutly/KeychainService.swift) - API key and encryption key storage
- [EncryptionService.swift](Minutly/EncryptionService.swift) - File encryption/decryption
- [AuditLogger.swift](Minutly/AuditLogger.swift) - Security event tracking
- [CloudDataDeletionService.swift](Minutly/CloudDataDeletionService.swift) - GDPR deletion + audit trail

### Testing
- [REGRESSION_TESTS.md](REGRESSION_TESTS.md) - Regression test documentation
- [TEST_SETUP_GUIDE.md](TEST_SETUP_GUIDE.md) - Test environment setup
- [TESTING_QUICK_REFERENCE.md](TESTING_QUICK_REFERENCE.md) - Quick testing commands
- **Note**: The MinutlyTests target must be added to the Xcode project before test commands will work. See TEST_SETUP_GUIDE.md.

## Semantic Code Search with mgrep

This project uses **mgrep** for semantic code search (~50% token reduction for codebase exploration).

```bash
# Setup
npm install -g @mixedbread/mgrep
export MXBAI_API_KEY=your_api_key_here
mgrep install-claude-code
mgrep watch  # Background indexing
```

Use mgrep for intent-based searches ("where is encryption handled?"), feature flow tracing, and cross-cutting concerns. Use traditional grep for exact symbol lookups.

See [.mgrepignore](.mgrepignore) for exclusion patterns.

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
4. **Audit log security events** using AuditLogger

### Common Tasks

#### Adding a New Transcription Provider

1. Create new service class with `transcribe(audioURL:languageCode:progressHandler:)` method
2. Add provider case to `transcriptionProvider` UserDefaults picker in SettingsView.swift
3. Add routing logic in TranscriptionService.transcribe() alongside existing Apple/AssemblyAI/OpenAI branches
4. Update API key storage in KeychainService if needed

#### Modifying Recording Behavior

1. Core logic is in `ScreenRecorder` class
2. Pre-buffering logic uses circular buffer pattern
3. Encryption happens automatically via EncryptionService
4. Update MenuBarController for status indicators

#### Updating Onboarding Flow

1. State is managed by OnboardingState.swift (central state machine)
2. Pages defined in OnboardingContainerView.swift
3. Re-enable by changing `if false` to `if !onboardingCompleted` in MinutlyApp.swift:65
4. Reset available in SettingsView.swift

## Testing

### Running Tests

> **Important**: The MinutlyTests target is not currently in the Xcode project. Follow TEST_SETUP_GUIDE.md Step 1 to add it before running tests.

```bash
# Run all tests (after adding test target)
xcodebuild test -scheme Minutly -destination 'platform=macOS'
```

RegressionTests.swift contains 6 tests. See [REGRESSION_TESTS.md](REGRESSION_TESTS.md) for details.

## User Defaults Keys

### Core Settings
- `transcriptionProvider` - Selected provider (`"apple"`, `"assemblyai"`, `"openai"`) - default: `"apple"`
- `transcriptionLanguages` - Comma-separated language codes (e.g., `"en"`, `"fr,en"`) - default: `"en"`
- `enableMeetingDetection` - Calendar integration toggle
- `enableMenuBarMode` - Menu bar vs dock mode

### Summarization Settings
- `summaryModel` - GPT model selection - default: `"gpt-3.5-turbo"`
- `summaryType` - Summary template (`"keypoints_tasks"`, `"executive"`, `"technical"`, `"sales"`)
- `customSummaryPrompt` - Advanced prompt editor content
- `customSummaryInstructions` - Simple instruction mode content
- `showAdvancedPromptEditor` - Toggle between simple/advanced prompt modes

### Onboarding State
- `onboardingCompleted` - First-run setup completion
- `currentOnboardingPage` - Onboarding progress (1-3)
- `transcriptionAPIConfigured` - AssemblyAI key saved during onboarding
- `summarizationAPIConfigured` - OpenAI key saved during onboarding

## API Keys & Credentials

All API keys are stored securely in macOS Keychain via KeychainService:

- `assemblyai` - AssemblyAI API key (Keychain account: `api_key_assemblyai`)
- `openai` - OpenAI API key (Keychain account: `api_key_openai`)
- `com.minutly.encryption_key` - Master encryption key (Keychain account: `api_key_com.minutly.encryption_key`)

Access via:
```swift
try KeychainService.shared.retrieveAPIKey(for: "assemblyai")
try KeychainService.shared.saveAPIKey(key, for: "openai")
```

## Build Configuration

- **Minimum macOS Version**: 15.7 (Sequoia)
- **Swift Version**: 5.0
- **Xcode Project**: `Minutly.xcodeproj`
- **App Identifier (Debug)**: `Ugitech.Minutly`
- **App Identifier (Release)**: `com.minutly.minutlyapp`

## External Dependencies

The app uses native frameworks only:
- SwiftUI (UI)
- AVFoundation (Audio)
- Speech (Apple Speech Recognition)
- CryptoKit (Encryption)
- EventKit (Calendar)
- Security (Keychain)
- UserNotifications (Meeting alerts)

No third-party package dependencies required.

## Git Workflow

- **Main Branch**: `main` - Production-ready code
- **Development Branches**: Feature branches for active work

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
- **Network**: API calls use retry logic

## Privacy & Compliance

- Audio recordings encrypted at rest (AES-256-GCM)
- Transcription text and summary JSON stored as plaintext
- No telemetry or analytics tracking
- User controls all cloud uploads
- Transparent API usage in settings
- Audit logging for security events
- CloudDataDeletionService handles GDPR-style deletion requests against AssemblyAI with persistent audit trail
- MeetingConfirmationManager persists per-meeting consent records to disk

## Onboarding Design System

For onboarding UI patterns (progress indicators, text fields, buttons, layout, colors), see [ONBOARDING_DESIGN_SYSTEM.md](ONBOARDING_DESIGN_SYSTEM.md).

Reference implementation: [OnboardingTranscriptionSetupView.swift](Minutly/OnboardingTranscriptionSetupView.swift)

---

**Last Updated**: 2026-04-01
**Project Version**: Active Development

**mgrep Integration**: Active (semantic code search enabled)
