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

## Semantic Code Search with mgrep

### Overview

This project uses **mgrep** for semantic code search, enabling natural language queries that significantly reduce Claude Code token usage (~50% reduction) and accelerate codebase exploration.

### Installation & Setup

**Install mgrep:**
```bash
npm install -g @mixedbread/mgrep
export MXBAI_API_KEY=your_api_key_here
mgrep install-claude-code
```

**Index the repository:**
```bash
cd /Users/benjaminpatin/Documents/French\ SaaS/Minutly/Minutly
mgrep watch  # Runs in background, continuously indexes changes
```

### When to Use mgrep vs Traditional grep

**Use mgrep for:**
- Intent-based searches: "where is encryption handled?"
- Feature flow understanding: "trace the recording lifecycle"
- Cross-cutting concerns: "find all API key usage"
- Conceptual queries: "show me async operations that update UI"

**Use traditional grep for:**
- Exact symbol searches: finding specific function/variable names
- Pattern matching: regex-based searches
- Single-file targeted searches

### Common Semantic Queries for Minutly

#### Security Pattern Discovery
```bash
mgrep "where are API keys stored and validated?"
mgrep "show me all encryption and decryption operations"
mgrep "find all places where sensitive data could be logged"
mgrep "where is certificate pinning implemented?"
mgrep "what operations should be audit logged but aren't?"
```

#### Async/Concurrency Tracking
```bash
mgrep "find all async operations that update UI state"
mgrep "show me Task blocks without MainActor protection"
mgrep "where could race conditions occur in recording flow?"
mgrep "map the async dependency chain for recording startup"
```

#### Feature Flow Understanding
```bash
mgrep "trace the complete recording lifecycle from start to encryption"
mgrep "what happens when user switches transcription providers?"
mgrep "show me the entire onboarding flow and state transitions"
mgrep "where does pre-buffering start and stop?"
```

#### Code Quality Improvements
```bash
mgrep "find error handlers that fail silently"
mgrep "show inconsistent error messages for the same operation"
mgrep "where is the emoji logging convention not followed?"
mgrep "find duplicate API client patterns"
```

#### Web Search Integration
```bash
mgrep --web "SwiftUI best practices for background audio recording"
mgrep --web --answer "How should I handle AES-256-GCM encryption in Swift?"
```

### Benefits

- **Token Efficiency**: Reduces Claude Code token usage by ~50% during exploration
- **Faster Discovery**: Single semantic query vs. multiple grep patterns + file reads
- **Contextual Understanding**: Returns results with semantic relevance ranking
- **Team Collaboration**: Cloud-backed index shared across developers

### Files & Configuration

- [.mgrepignore](.mgrepignore) - Exclusion patterns (Xcode artifacts, build files)
- Index storage: Cloud-backed (automatic, no manual management)
- Background indexing: Runs via `mgrep watch` (continuous updates)

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

## Onboarding Design System

### Design Principles

All onboarding pages must follow these consistent design patterns for a cohesive user experience.

### Progress Indicator (3 Steps)

**Structure**: Use `ZStack` with two layers:
1. **Background layer**: Continuous progress lines (no gaps)
2. **Foreground layer**: Numbered circles on top

```swift
ZStack(alignment: .center) {
    // Background progress lines layer
    HStack(spacing: 0) {
        // Line 1 - Gradient from black to gray (for active step)
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [.black, Color(red: 0.85, green: 0.85, blue: 0.85)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 8)

        // Line 2 - Gray (for inactive steps)
        Rectangle()
            .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
            .frame(height: 8)
    }

    // Circles layer on top
    HStack(spacing: 0) {
        // Active step - Black circle with white number
        Circle()
            .fill(.black)
            .frame(width: 50, height: 50)
            .overlay(
                Text("1")
                    .font(Font.custom("Arial", size: 28).weight(.bold))
                    .foregroundColor(.white)
            )

        Spacer()

        // Inactive step - Gray circle with black number
        Circle()
            .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
            .frame(width: 50, height: 50)
            .overlay(
                Text("2")
                    .font(Font.custom("Arial", size: 28).weight(.bold))
                    .foregroundColor(.black)
            )

        Spacer()

        Circle()
            .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
            .frame(width: 50, height: 50)
            .overlay(
                Text("3")
                    .font(Font.custom("Arial", size: 28).weight(.bold))
                    .foregroundColor(.black)
            )
    }
}
.frame(width: geometry.size.width * 0.5, alignment: .center)
```

**Key Rules**:
- NO text labels below circles (no "Step 1", "Step 2", etc.)
- Lines extend continuously behind circles (no gaps)
- Active step: Black circle + white text
- Inactive steps: Gray circle (`Color(red: 0.85, green: 0.85, blue: 0.85)`) + black text
- Progress indicator width: 50% of screen width, centered

### Text Field Styling

```swift
TextField("Placeholder text here", text: $binding)
    .font(Font.custom("Arial", size: 16))
    .foregroundColor(.black)  // Input text is black
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color(red: 0.85, green: 0.85, blue: 0.85))  // Gray background
    .cornerRadius(16)
    .textFieldStyle(.plain)  // CRITICAL: Removes default borders
```

**Key Rules**:
- Background: Gray `Color(red: 0.85, green: 0.85, blue: 0.85)`
- Text color: Black `.foregroundColor(.black)`
- MUST use `.textFieldStyle(.plain)` to remove default borders
- No white background, no borders

### Navigation Buttons

**Button Structure** (simple, no nested VStacks):

```swift
HStack(alignment: .center, spacing: min(400, geometry.size.width * 0.3)) {
    // Skip button - Black background, white text
    Button(action: { onboardingState.skipPage() }) {
        Text("Skip")
            .font(Font.custom("Arial", size: min(30, geometry.size.height * 0.048)).weight(.bold))
            .foregroundColor(.white)
    }
    .buttonStyle(.plain)  // CRITICAL: Removes default button styling
    .frame(width: min(302, geometry.size.width * 0.25), height: 50)
    .background(.black)
    .cornerRadius(16)

    // Next button - Gray background, white text
    Button(action: { onboardingState.nextPage() }) {
        Text("Next")
            .font(Font.custom("Arial", size: min(30, geometry.size.height * 0.048)).weight(.bold))
            .foregroundColor(.white)
    }
    .buttonStyle(.plain)  // CRITICAL: Removes default button styling
    .frame(width: min(302, geometry.size.width * 0.25), height: 50)
    .background(Color(red: 0.85, green: 0.85, blue: 0.85))
    .cornerRadius(16)
}
```

**Key Rules**:
- MUST use `.buttonStyle(.plain)` to remove default macOS button styling
- Skip button: Black background (`.black`) + white text
- Next button: Gray background (`Color(red: 0.85, green: 0.85, blue: 0.85)`) + white text
- Go Back button (if needed): Gray background (`Color(red: 0.5, green: 0.5, blue: 0.5)`) + white text
- Keep it simple: No nested VStacks, no description text below buttons
- Button height: 50px fixed
- Button width: Responsive `min(302, geometry.size.width * 0.25)`

### Layout Structure

All onboarding pages should follow this structure:

```swift
GeometryReader { geometry in
    ScrollView {
        VStack(spacing: 0) {
            // Top whitespace
            Spacer()
                .frame(height: max(20, geometry.size.height * 0.03))

            // Progress header (if applicable)
            VStack(spacing: 16) {
                Text("Configure your app")
                    .font(Font.custom("Arial", size: min(50, geometry.size.height * 0.08)).weight(.bold))
                    .foregroundColor(.black)

                // Progress indicator here
            }
            .padding(.bottom, max(20, geometry.size.height * 0.03))

            // Content area
            VStack(alignment: .leading, spacing: 6) {
                // Page-specific content
            }
            .padding(.horizontal, 60)
            .padding(.bottom, max(20, geometry.size.height * 0.03))

            // Navigation buttons
            HStack(alignment: .center, spacing: min(400, geometry.size.width * 0.3)) {
                // Buttons here
            }
            .padding(.horizontal, 60)
            .padding(.bottom, max(20, geometry.size.height * 0.03))
        }
        .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.white)
}
```

### Responsive Font Sizing

Use `min()` for responsive font sizes based on window height:

```swift
.font(Font.custom("Arial", size: min(50, geometry.size.height * 0.08)).weight(.bold))  // Large title
.font(Font.custom("Arial", size: min(30, geometry.size.height * 0.048)).weight(.bold)) // Headings
.font(Font.custom("Arial", size: min(28, geometry.size.height * 0.044)))              // Body text
.font(Font.custom("Arial", size: min(25, geometry.size.height * 0.04)).weight(.bold)) // Sub-headings
```

### Color Palette

- **Black**: `.black` - Active elements, primary buttons, active step indicators
- **Gray**: `Color(red: 0.85, green: 0.85, blue: 0.85)` - Inactive elements, text fields, secondary buttons
- **White**: `.white` - Button text, background, active step numbers
- **Success Green**: `Color(red: 0.91, green: 0.96, blue: 0.91)` - Success message backgrounds
- **Error Red**: `Color(red: 1.0, green: 0.92, blue: 0.93)` - Error message backgrounds

### Critical Implementation Notes

1. **ALWAYS use `.buttonStyle(.plain)`** on buttons to remove default macOS styling
2. **ALWAYS use `.textFieldStyle(.plain)`** on text fields to remove borders
3. **Use ZStack for progress indicator** to layer lines behind circles seamlessly
4. **Use GeometryReader** for responsive layouts that work at all window sizes
5. **Keep button structure simple** - no unnecessary nested VStacks or extra text
6. **Follow the exact color values** - consistency is critical for professional appearance

### Reference Implementation

See [OnboardingTranscriptionSetupView.swift](Minutly/OnboardingTranscriptionSetupView.swift) for complete reference implementation of these design patterns.

---

**Last Updated**: 2025-12-22
**Project Version**: Active Development
**Documentation Status**: Complete

**mgrep Integration**: Active (semantic code search enabled)
