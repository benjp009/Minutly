# Minutly Testing Quick Reference

## 🚀 Quick Commands

### Run All Tests
```bash
⌘+U  # In Xcode
```

### Run Specific Test
```bash
xcodebuild test -scheme Minutly -destination 'platform=macOS' \
  -only-testing:MinutlyTests/RegressionTests/testRecordingSuccess
```

### Run from Terminal
```bash
cd "/Users/benjaminpatin/Documents/French SaaS/Minutly/Minutly"
xcodebuild test -scheme Minutly -destination 'platform=macOS'
```

## ✅ Test Checklist

Before committing code, verify:

- [ ] All regression tests pass (`⌘+U`)
- [ ] No new warnings in test output
- [ ] Test execution time < 30 seconds
- [ ] Manual smoke test of changed functionality

## 🧪 Test Suite Coverage

| Test Name | What It Tests | Expected Time |
|-----------|---------------|---------------|
| `testRecordingSuccess` | Recording creation & encryption | < 2s |
| `testPlaybackSuccess` | Decryption & playback | < 2s |
| `testEncryptionKeyValidity` | Key persistence & consistency | < 1s |
| `testEndToEndRecordingPipeline` | Full recording workflow | < 3s |

## 🔴 Critical Test Failures

### Encryption Key Changed
```
❌ REGRESSION FAILURE: Encryption key changed between retrievals
```
**Action:** Check `EncryptionService.getMasterKey()` - likely base64 encoding issue

### Decrypted Data Mismatch
```
❌ REGRESSION FAILURE: Decrypted data does not match original
```
**Action:** Check encryption/decryption logic - possible key or algorithm issue

### Empty Recording File
```
❌ REGRESSION FAILURE: Encrypted recording file is empty
```
**Action:** Check file write operations and encryption service

## 📋 When to Run Tests

### ALWAYS
- Before committing to `main` or `dev-branch`
- Before creating a pull request
- After modifying core files (see below)

### Core Files Requiring Tests
- `ScreenRecorder.swift`
- `EncryptionService.swift`
- `ContentView.swift` (playback code)
- `WaveformView.swift`
- `KeychainService.swift`
- `*.entitlements`

## 🛠️ Quick Fixes

### Tests Won't Run
```bash
# Clean build folder
⌘+Shift+K

# Rebuild
⌘+B

# Try again
⌘+U
```

### Keychain Errors
1. Open Keychain Access
2. Search for "minutly"
3. Delete test-related entries
4. Re-run tests

### Module Not Found
1. Verify `@testable import Minutly`
2. Check test target has Minutly.app linked
3. Clean and rebuild

## 📊 Success Criteria

```
✅ 4/4 tests passed
✅ 0 failures
✅ Execution time < 30s
✅ No warnings
```

## 🔗 Documentation Links

- **Full Test Documentation:** [REGRESSION_TESTS.md](REGRESSION_TESTS.md)
- **Setup Guide:** [TEST_SETUP_GUIDE.md](TEST_SETUP_GUIDE.md)
- **Test Source:** [MinutlyTests/RegressionTests.swift](MinutlyTests/RegressionTests.swift)

## 💡 Pro Tips

1. **Run tests in background:** Tests run while you continue coding
2. **Use Test Navigator:** `⌘+6` → Click ▶️ next to individual test
3. **View test output:** Right-click test → "View Test Results"
4. **Re-run failed tests only:** Xcode automatically highlights failed tests

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| "Directory already exists" | Normal - tests clean up automatically |
| "Keychain access denied" | Reset keychain permissions |
| "No such module" | Clean build folder and rebuild |
| Tests timeout | Check for infinite loops or hanging operations |

## 📞 Need Help?

1. Check console output for specific error messages
2. Review [REGRESSION_TESTS.md](REGRESSION_TESTS.md) for detailed info
3. Check git history for recent changes to test files
4. Contact development team

---

**Keep this handy!** Print or bookmark for quick reference.
