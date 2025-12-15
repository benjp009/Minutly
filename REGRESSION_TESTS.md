# Minutly Regression Tests

## Overview

This document describes the regression test suite for Minutly. These tests ensure that core functionality remains intact when implementing new features or making code changes.

## Purpose

The regression tests verify three critical aspects of the Minutly application:

1. **Recording Success** - Ensures recordings can be created and encrypted properly
2. **Playback Success** - Ensures encrypted recordings can be decrypted and played back
3. **Encryption Key Validity** - Ensures the encryption key is consistently stored and retrieved

## Test Suite Location

```
MinutlyTests/RegressionTests.swift
```

## Running the Tests

### Option 1: Xcode GUI

1. Open `Minutly.xcodeproj` in Xcode
2. Press `⌘+U` (Command+U) to run all tests
3. Or navigate to the Test Navigator (⌘+6) and run individual tests

### Option 2: Command Line

```bash
cd "/Users/benjaminpatin/Documents/French SaaS/Minutly/Minutly"
xcodebuild test -scheme Minutly -destination 'platform=macOS'
```

### Option 3: Run Specific Test

```bash
xcodebuild test -scheme Minutly -destination 'platform=macOS' -only-testing:MinutlyTests/RegressionTests/testRecordingSuccess
```

## Test Descriptions

### 1. testRecordingSuccess

**What it tests:**
- Audio file can be created
- File can be encrypted using EncryptionService
- Encrypted file exists and has content
- Encrypted file can be decrypted
- Decrypted data matches original

**Expected outcome:**
```
✅ Test directory created
✅ Encrypted recording file exists
✅ Encrypted file has content
✅ Decrypted data matches original
✅ REGRESSION PASS: Recording success test passed
```

**Failure indicators:**
```
❌ REGRESSION FAILURE: Encrypted recording file does not exist
❌ REGRESSION FAILURE: Encrypted recording file is empty
❌ REGRESSION FAILURE: Decrypted data does not match original
```

### 2. testPlaybackSuccess

**What it tests:**
- Encrypted recording can be decrypted
- Decrypted audio can be loaded into AVAudioPlayer
- Audio player can prepare for playback
- Audio has valid duration

**Expected outcome:**
```
✅ Test recording created
✅ Audio player created successfully
✅ Audio duration is valid
✅ Audio player prepared successfully
✅ REGRESSION PASS: Playback success test passed
```

**Failure indicators:**
```
❌ REGRESSION FAILURE: Test recording does not exist
❌ REGRESSION FAILURE: Audio player could not be created
❌ REGRESSION FAILURE: Audio duration is zero
❌ REGRESSION FAILURE: Audio player failed to prepare
```

### 3. testEncryptionKeyValidity

**What it tests:**
- Encryption key can be created/retrieved
- Key is 256-bit (32 bytes)
- Same key is returned on multiple retrievals
- Key can encrypt and decrypt data
- Encryption uses proper nonces (different output each time)

**Expected outcome:**
```
🔑 First key retrieval: 32 bytes
🔑 Second key retrieval: 32 bytes
🔒 Encrypted [N] bytes to [M] bytes
🔓 Decrypted [M] bytes to [N] bytes
✅ REGRESSION PASS: Encryption key validity test passed
```

**Failure indicators:**
```
❌ REGRESSION FAILURE: Encryption key is not 256-bit (32 bytes)
❌ REGRESSION FAILURE: Encryption key changed between retrievals
❌ REGRESSION FAILURE: Decrypted data does not match original
❌ REGRESSION FAILURE: Encryption produces identical output (nonce not random)
```

### 4. testEndToEndRecordingPipeline

**What it tests:**
- Complete recording workflow from audio generation to playback
- Audio generation works correctly
- Encryption produces non-empty files
- Encrypted files are not readable as WAV (proper encryption)
- Decryption restores original data size
- Decrypted audio is valid and playable

**Expected outcome:**
```
1️⃣ Generated test audio: [N] bytes
2️⃣ Encrypted to: [M] bytes
3️⃣ Decrypted to: [N] bytes
4️⃣ Audio file readable: [X] frames
5️⃣ Audio player ready: [Y] seconds
✅ REGRESSION PASS: End-to-end pipeline test passed
```

**Failure indicators:**
```
❌ REGRESSION FAILURE: Encryption produced empty file
❌ REGRESSION FAILURE: Encrypted file is readable as WAV (not properly encrypted)
❌ REGRESSION FAILURE: Decrypted data size does not match original
❌ REGRESSION FAILURE: Decrypted audio has no frames
❌ REGRESSION FAILURE: Audio player failed to prepare
```

## When to Run These Tests

### ALWAYS run before:
- Committing changes to recording functionality
- Committing changes to encryption/decryption code
- Committing changes to playback functionality
- Releasing a new version
- Merging feature branches

### Recommended to run:
- After modifying ScreenRecorder.swift
- After modifying EncryptionService.swift
- After modifying ContentView.swift playback code
- After modifying WaveformView.swift
- After modifying KeychainService.swift
- After changing entitlements

## Continuous Integration

### GitHub Actions Example

```yaml
name: Regression Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v2
    - name: Run regression tests
      run: |
        cd "/Users/benjaminpatin/Documents/French SaaS/Minutly/Minutly"
        xcodebuild test -scheme Minutly -destination 'platform=macOS'
```

## Test Maintenance

### Adding New Tests

When adding new core functionality, add a corresponding regression test:

1. Add test method to `RegressionTests.swift`
2. Follow naming convention: `test[Feature][Aspect]`
3. Add documentation to this file
4. Ensure test is idempotent (can run multiple times)
5. Clean up resources in tearDown

### Test Data

Tests use:
- Temporary directories (auto-created and cleaned)
- Generated sine wave audio (440 Hz, configurable duration)
- In-memory encryption operations
- Shared EncryptionService instance

### Common Issues

**Test fails with "Keychain error":**
- Ensure app is properly signed
- Check entitlements are correct
- Try resetting Keychain access in Xcode

**Test fails with "File not found":**
- Check that setUp creates test directory
- Verify cleanup in tearDown isn't running prematurely
- Check file permissions

**Test fails with "Encryption key mismatch":**
- **CRITICAL**: This indicates the encryption key bug has returned
- Verify EncryptionService.getMasterKey() uses `Data(base64Encoded:)`
- Check KeychainService stores and retrieves as base64

## Success Criteria

All tests must pass with:
- ✅ 100% pass rate
- ✅ No warning messages
- ✅ No memory leaks
- ✅ Execution time < 30 seconds total

## Contact

For issues with regression tests, contact the development team or file an issue in the project repository.

---

**Last Updated:** 2025-12-14
**Test Suite Version:** 1.0
**Maintainer:** Development Team
