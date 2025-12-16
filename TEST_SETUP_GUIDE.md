# Minutly Test Setup Guide

## Quick Start

This guide helps you set up the regression test suite in Xcode.

## Files Created

```
MinutlyTests/
├── RegressionTests.swift      # Main test suite
└── Info.plist                 # Test bundle configuration

REGRESSION_TESTS.md            # Detailed test documentation
TEST_SETUP_GUIDE.md           # This file
```

## Xcode Setup Steps

### Step 1: Add Test Target (If Not Already Present)

1. Open `Minutly.xcodeproj` in Xcode
2. Select the project in the navigator
3. Click the `+` button at the bottom of the targets list
4. Choose "macOS Unit Testing Bundle"
5. Name it: `MinutlyTests`
6. Set Product Name: `MinutlyTests`
7. Set Bundle Identifier: `Ugitech.MinutlyTests`
8. Click Finish

### Step 2: Add Test Files to Target

1. In Xcode, right-click on the project navigator
2. Select "Add Files to Minutly..."
3. Navigate to `MinutlyTests/` folder
4. Select `RegressionTests.swift`
5. Ensure "Copy items if needed" is UNCHECKED
6. Ensure `MinutlyTests` target is CHECKED
7. Click Add

### Step 3: Configure Test Target

1. Select `MinutlyTests` target in project settings
2. Go to "Build Settings"
3. Set "Swift Language Version" to match main app (Swift 5)
4. Set "macOS Deployment Target" to match main app

### Step 4: Link Main App to Tests

1. Select `MinutlyTests` target
2. Go to "General" tab
3. Under "Frameworks and Libraries", click `+`
4. Add `Minutly.app` (if not already added)

### Step 5: Verify Test Discovery

1. Press `⌘+6` to open Test Navigator
2. You should see:
   - MinutlyTests
     - RegressionTests
       - testRecordingSuccess
       - testPlaybackSuccess
       - testEncryptionKeyValidity
       - testEndToEndRecordingPipeline

## Running Tests

### Run All Tests
Press `⌘+U` (Command+U)

### Run Single Test
1. Open Test Navigator (`⌘+6`)
2. Click the ▶️ icon next to the test name

### Run from Terminal
```bash
cd "/Users/benjaminpatin/Documents/French SaaS/Minutly/Minutly"
xcodebuild test -scheme Minutly -destination 'platform=macOS'
```

## Expected Output

### Success
```
Test Suite 'RegressionTests' passed at 2025-12-14 10:30:00.123
✅ REGRESSION PASS: Recording success test passed
✅ REGRESSION PASS: Playback success test passed
✅ REGRESSION PASS: Encryption key validity test passed
✅ REGRESSION PASS: End-to-end pipeline test passed

Executed 4 tests, with 0 failures (0 unexpected) in 5.234 seconds
```

### Failure Example
```
❌ Test Case 'RegressionTests.testEncryptionKeyValidity' failed (0.123 seconds)
❌ REGRESSION FAILURE: Encryption key changed between retrievals

Expected: <32 bytes: 0x1234...>
Got: <32 bytes: 0x5678...>
```

## Troubleshooting

### Issue: "No such module 'Minutly'"

**Solution:**
1. Ensure main app target builds successfully first
2. In Test target Build Settings, check "SWIFT_INCLUDE_PATHS"
3. Clean build folder (`⌘+Shift+K`)
4. Rebuild (`⌘+B`)

### Issue: "Cannot find 'ScreenRecorder' in scope"

**Solution:**
1. Ensure `@testable import Minutly` is at top of test file
2. Check that ScreenRecorder.swift is part of Minutly target
3. Verify access control (should be `internal` or `public`, not `private`)

### Issue: Test fails with Keychain error

**Solution:**
1. Ensure app is properly signed
2. Check entitlements in test target match main app
3. Try: Keychain Access → Delete test-related entries → Retry

### Issue: "Directory already exists" error

**Solution:**
This is normal if tests are run multiple times. The test cleanup should handle this. If it persists:
1. Manually delete: `/tmp/MinutlyRegressionTests/`
2. Restart Xcode
3. Re-run tests

## Best Practices

### Before Committing Code

```bash
# Run all regression tests
xcodebuild test -scheme Minutly -destination 'platform=macOS'

# Verify all pass before committing
git add .
git commit -m "feat: your feature description"
```

### Git Hook Integration (Optional)

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash

echo "Running regression tests before commit..."
cd "/Users/benjaminpatin/Documents/French SaaS/Minutly/Minutly"
xcodebuild test -scheme Minutly -destination 'platform=macOS' -quiet

if [ $? -ne 0 ]; then
    echo "❌ Regression tests failed. Commit aborted."
    exit 1
fi

echo "✅ All regression tests passed"
exit 0
```

Make executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Test Coverage

The regression test suite currently covers:

- ✅ Recording encryption workflow
- ✅ Playback decryption workflow
- ✅ Encryption key persistence
- ✅ End-to-end recording pipeline

### Future Test Additions

Consider adding tests for:
- [ ] Waveform generation from encrypted files
- [ ] Recording rename functionality
- [ ] Transcript generation
- [ ] Export functionality (encrypted vs decrypted)
- [ ] Multiple simultaneous recordings
- [ ] Recording deletion and cleanup

## Performance Benchmarks

Expected test execution times (on modern Mac):

| Test | Expected Time |
|------|---------------|
| testRecordingSuccess | < 2s |
| testPlaybackSuccess | < 2s |
| testEncryptionKeyValidity | < 1s |
| testEndToEndRecordingPipeline | < 3s |
| **Total Suite** | **< 10s** |

If tests take significantly longer, investigate:
- Disk I/O performance
- Encryption key retrieval delays
- Audio generation performance

## Continuous Integration

### GitHub Actions

Create `.github/workflows/tests.yml`:

```yaml
name: Regression Tests

on:
  push:
    branches: [ main, dev-branch ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable

    - name: Run Tests
      run: |
        cd "/Users/benjaminpatin/Documents/French SaaS/Minutly/Minutly"
        xcodebuild test \
          -scheme Minutly \
          -destination 'platform=macOS' \
          -quiet

    - name: Upload Test Results
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: |
          build/Logs/Test/*.xcresult
```

## Support

If you encounter issues:

1. Check [REGRESSION_TESTS.md](REGRESSION_TESTS.md) for detailed test documentation
2. Review Xcode console output for specific error messages
3. Verify all test files are properly added to test target
4. Ensure main app builds successfully before running tests

---

**Created:** 2025-12-14
**Version:** 1.0
**Maintainer:** Development Team
