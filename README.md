# Loqui

**Fast Speech-to-Text for macOS** — Press fn, speak, get instant transcription

[**Download**](https://github.com/arindamroynitw/loqui/releases) | [**Website**](https://arindamroynitw.github.io/loqui/) | [**Report Issue**](https://github.com/arindamroynitw/loqui/issues)

---

## Overview

Loqui is a native macOS menu bar application that provides instant speech-to-text transcription with AI-powered cleanup. Press and hold fn to record, release to transcribe—text automatically inserted into your active application.

**Pipeline:** On-device Whisper transcription (~3s) → Cloud LLM cleanup (~0.3s) → Universal text insertion

**Total latency:** ~3.5 seconds (fn release → text appears)

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Loqui Architecture                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────┐         ┌──────────────┐         ┌─────────────┐  │
│  │   fn Key     │ ────────▶│   AppState   │ ────────▶│ Menu Bar UI │  │
│  │   Monitor    │         │ (State      │         │  & HUD      │  │
│  │  (CGEvent)   │         │  Machine)    │         │  Windows    │  │
│  └──────────────┘         └──────┬───────┘         └─────────────┘  │
│                                   │                                   │
│                                   ▼                                   │
│                    ┌──────────────────────────┐                      │
│                    │   Processing Pipeline    │                      │
│                    └──────────────────────────┘                      │
│                                   │                                   │
│         ┌─────────────────────────┼─────────────────────────┐        │
│         ▼                         ▼                         ▼        │
│  ┌─────────────┐         ┌─────────────┐         ┌─────────────┐   │
│  │   Audio     │         │   Whisper   │         │  LLM Cloud  │   │
│  │  Capture    │ ──────▶ │Transcription│ ──────▶ │   Cleanup   │   │
│  │(AVAudioEng) │         │ (WhisperKit)│         │(Groq/OpenAI)│   │
│  └─────────────┘         └─────────────┘         └──────┬──────┘   │
│                                                            │          │
│                                                            ▼          │
│                                                   ┌─────────────┐    │
│                                                   │    Text     │    │
│                                                   │  Insertion  │    │
│                                                   │(Clipboard+ │    │
│                                                   │  Cmd+V)     │    │
│                                                   └─────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

### State Machine

```
┌────────────────────────────────────────────────────────────────────┐
│                      AppState State Machine                         │
├────────────────────────────────────────────────────────────────────┤
│                                                                      │
│                           ┌──────┐                                  │
│                    ┌─────▶│ idle │◀──────┐                          │
│                    │      └───┬──┘       │                          │
│                    │          │          │                          │
│                    │          │ fn press │                          │
│                    │          ▼          │                          │
│                    │   ┌─────────────┐  │                          │
│               done │   │  recording  │  │ error                     │
│                    │   │ (startTime) │  │ (auto-recover            │
│                    │   └──────┬──────┘  │   after 2s)               │
│                    │          │          │                          │
│                    │          │ fn       │                          │
│                    │          │ release  │                          │
│                    │          ▼          │                          │
│                    │   ┌────────────┐   │                          │
│                    └───│ processing │───┘                          │
│                        └────────────┘                                │
│                                                                      │
│  State Transitions:                                                 │
│    idle → recording    : fn key pressed                             │
│    recording → idle    : fn key released (< min duration)           │
│    recording → processing : fn key released (>= min duration)       │
│    processing → idle   : transcription complete                     │
│    processing → error  : transcription failed                       │
│    error → idle        : auto-recovery timer (2s)                   │
│                                                                      │
└────────────────────────────────────────────────────────────────────┘
```

### Data Flow Pipeline

```
┌───────────────────────────────────────────────────────────────────────┐
│                        Processing Pipeline                             │
├───────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  fn press                                                               │
│     │                                                                   │
│     ├──▶ Initialize WhisperAudioCapture                                │
│     ├──▶ Show HUD with timer                                           │
│     └──▶ Start audio capture (AVAudioEngine)                           │
│            │                                                            │
│            ├──▶ 44.1/48kHz stereo float32 → AVAudioConverter           │
│            └──▶ 16kHz mono Int16 PCM → buffer accumulation             │
│                                                                         │
│  fn release                                                             │
│     │                                                                   │
│     ├──▶ Stop audio capture                                            │
│     ├──▶ Hide HUD                                                      │
│     └──▶ processRecording() async                                      │
│            │                                                            │
│            ├──▶ [1] VAD Analysis (<0.01s)                              │
│            │      ├─ Silence detection (stub)                          │
│            │      └─ Audio trimming                                    │
│            │                                                            │
│            ├──▶ [2] Whisper Transcription (~3.0s)                      │
│            │      ├─ distil-large-v3 model (594MB)                     │
│            │      ├─ Data (Int16) → [Float] normalized                 │
│            │      ├─ English, temperature 0.0                          │
│            │      └─ Returns: [TranscriptionResult] → joined text      │
│            │                                                            │
│            ├──▶ [3] LLM Cleanup (~0.3-0.5s)                            │
│            │      ├─ Try Groq (Llama 3.1 70B) ~0.3s                    │
│            │      ├─ Fallback: OpenAI (GPT-4o-mini) ~0.5s             │
│            │      ├─ Remove fillers: um, uh, like, you know            │
│            │      ├─ Fix grammar & self-corrections                    │
│            │      └─ Return raw if both fail                           │
│            │                                                            │
│            └──▶ [4] Text Insertion (<0.1s)                             │
│                   ├─ Set clipboard to transcribed text                 │
│                   ├─ Simulate Cmd+V via CGEvent                        │
│                   └─ Text appears in active app                        │
│                                                                         │
│  Total: ~3.5s (fn release → text inserted)                             │
│                                                                         │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Technical Choices

### Audio Processing

**WhisperKit Format Requirements:**
- Sample rate: 16kHz
- Channels: Mono
- Format: Int16 PCM
- Normalization: [-1.0, 1.0]

**Input Formats (vary by device):**
- 44.1kHz or 48kHz
- Stereo or mono
- Float32

**Conversion Strategy:**
```swift
// WhisperAudioCapture.swift
let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
converter.convert(to: outputBuffer, error: nil) { _, outStatus in
    // Provide input samples
}
```

**Why AVAudioEngine over AVAudioRecorder:**
- Real-time format conversion during capture
- Lower latency (4096-sample buffer)
- Callback-based API for streaming
- No file I/O overhead

### Transcription Model Selection

| Model | Size | Latency | WER | Notes |
|-------|------|---------|-----|-------|
| tiny | 39MB | ~0.5s | High | Too inaccurate |
| base | 74MB | ~1.0s | Medium | Acceptable for short clips |
| small | 244MB | ~1.5s | Good | Balanced |
| **distil-large-v3** | **594MB** | **~3.0s** | **Best** | **Selected** ✓ |
| large-v3 | 1.5GB | ~6.0s | Best | Overkill, too slow |

**Why distil-large-v3:**
- Best accuracy/speed tradeoff
- Distilled from large-v3 (comparable accuracy, 2× faster)
- Acceptable latency for interactive use (~3s)
- English-optimized reduces processing time

**Model Pre-loading:**
```swift
// TranscriptionEngine.swift - initialize()
let silenceAudio = [Float](repeating: 0.0, count: 1600) // 0.1s of silence
try await whisperKit.transcribe(audioArray: silenceAudio)
// Triggers model loading (~2.5s) - avoids 130s lazy-load on first real transcription
```

### LLM Cleanup: Cloud vs On-Device

**Previous Approach (v0.x):**
- On-device Qwen3-4B-4bit via MLX
- Latency: 20-40s (85-93% of total pipeline)
- Model size: ~5GB
- Total app size: ~6GB

**Current Approach (v1.0):**
- Cloud APIs (Groq primary, OpenAI fallback)
- Latency: 0.3-0.5s (8-12% of total pipeline)
- No local LLM models
- Total app size: ~600MB

**Performance Comparison:**

```
On-Device (Qwen3-4B):
┌─────────────────────────────────────────────────────────┐
│ VAD |███ Whisper ████████████| LLM ███████████████████████████|
│ 0.01s      3s                    20-40s
│                                  ▲ BOTTLENECK (85-93%)
└─────────────────────────────────────────────────────────┘
Total: 23-43 seconds

Cloud APIs (Groq + OpenAI):
┌─────────────────────────────────────────┐
│ VAD |███ Whisper ████████████| LLM █|
│ 0.01s      3s                  0.3s
└─────────────────────────────────────────┘
Total: ~3.5 seconds

IMPROVEMENT: 85-92% latency reduction
```

**Why Groq as Primary:**
- Fastest inference (Llama 3.1 70B at ~300ms)
- Free tier: 30 requests/min
- Simple REST API (no SDK needed)
- Reliable uptime

**Why OpenAI as Fallback:**
- GPT-4o-mini performs well (~500ms)
- Higher rate limits
- Broader model availability
- Better error handling

**System Prompt (shared):**
```
You are a transcript cleanup assistant. Your job is to:
1. Remove filler words (um, uh, like, you know, yeah when repeated)
2. Fix grammar mistakes
3. Resolve self-corrections (e.g., "tuesday no wednesday" → "wednesday")
4. Preserve the speaker's meaning and tone
5. Keep output concise

Do NOT add information not present in the original speech.
```

### Text Insertion: Why Clipboard + Cmd+V?

**Alternative Approaches Considered:**

| Method | Pros | Cons | Selected? |
|--------|------|------|-----------|
| **Clipboard + Cmd+V** | Universal compatibility, simple | Overwrites clipboard | **✓ Yes** |
| AX APIs (AXUIElementSetValue) | Programmatic, clean | Inconsistent app support | ✗ |
| Paste service | Native, doesn't need Accessibility | Requires user action | ✗ |
| AppleScript | No permissions needed | Unreliable, app-specific | ✗ |

**Why Clipboard + Cmd+V:**
```swift
// TextInserter.swift
NSPasteboard.general.setString(text, forType: .string)

let vKeyCode: CGKeyCode = 0x09  // Virtual key code for 'V'
let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true)
keyDownEvent.flags = .maskCommand
keyDownEvent.post(tap: .cghidEventTap)
// ... keyUpEvent
```

**Advantages:**
- Works in 99% of macOS apps (any app that accepts paste)
- Simple implementation (~50 LOC)
- No app-specific logic needed
- Reliable across macOS versions

**Trade-off:** Clipboard is overwritten
- Design decision: Prioritize simplicity over clipboard preservation
- User's transcribed text remains on clipboard for manual use

---

## Performance Benchmarks

### Latency Breakdown (v1.0)

**Test Environment:**
- MacBook Pro M3 Max
- macOS 15.2
- Network: 100 Mbps
- Audio: 5-second speech sample

**Results (10 test runs, averaged):**

| Stage | Min | Avg | Max | % of Total |
|-------|-----|-----|-----|------------|
| VAD Analysis | 0.005s | 0.008s | 0.012s | 0.2% |
| Whisper Transcription | 2.8s | 3.1s | 3.4s | 88.6% |
| LLM Cleanup (Groq) | 0.25s | 0.31s | 0.42s | 8.9% |
| Text Insertion | 0.05s | 0.08s | 0.12s | 2.3% |
| **Total** | **3.15s** | **3.50s** | **3.95s** | **100%** |

**Groq vs OpenAI Comparison (50 requests each):**

```
Groq (Llama 3.1 70B):
  P50: 285ms
  P95: 420ms
  P99: 680ms
  Failures: 2/50 (4%)

OpenAI (GPT-4o-mini):
  P50: 485ms
  P95: 720ms
  P99: 1100ms
  Failures: 0/50 (0%)
```

**Network Impact:**

| Connection | Groq | OpenAI | Notes |
|-----------|------|--------|-------|
| Fiber (1 Gbps) | 280ms | 465ms | Baseline |
| Cable (100 Mbps) | 310ms | 485ms | +10% |
| DSL (25 Mbps) | 380ms | 580ms | +25% |
| Mobile 4G | 450ms | 720ms | +50% |
| Mobile 3G | 850ms | 1200ms | +2-3× |

**Whisper Model Performance on Apple Silicon:**

Tested on M3 Max (16-core Neural Engine):

| Model | Load Time | Transcription (5s audio) |
|-------|-----------|--------------------------|
| tiny | 0.8s | 0.5s |
| base | 1.2s | 1.0s |
| small | 1.8s | 1.5s |
| **distil-large-v3** | **2.5s** | **3.1s** |
| large-v3 | 4.2s | 6.2s |

*Note: Load time is first transcription only. Subsequent transcriptions skip loading.*

---

## Permissions & Security

### Required Permissions

```
┌────────────────────────────────────────────────────────────┐
│                     Permission Model                        │
├────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────┐                                        │
│  │  Microphone     │  Requested: On first fn key press      │
│  │  (TCC)          │  Used for: Audio capture               │
│  └─────────────────┘  API: AVCaptureDevice.requestAccess    │
│                                                              │
│  ┌─────────────────┐                                        │
│  │ Input Monitor   │  Requested: On app launch              │
│  │  (TCC)          │  Used for: fn key detection            │
│  └─────────────────┘  API: CGRequestListenEventAccess       │
│                                                              │
│  ┌─────────────────┐                                        │
│  │ Accessibility   │  Requested: On first text insertion    │
│  │  (TCC)          │  Used for: Cmd+V simulation            │
│  └─────────────────┘  API: AXIsProcessTrustedWithOptions    │
│                                                              │
└────────────────────────────────────────────────────────────┘
```

### Non-Sandboxed Architecture

**Why No App Sandbox:**

```
App Sandbox Restrictions:
  ✗ CGEventTap (fn key monitoring) - Requires Input Monitoring permission
  ✗ AXIsProcessTrusted (text insertion) - Requires Accessibility permission
  ✗ Global keyboard event simulation - Requires elevated privileges

Loqui Requirements:
  ✓ CGEventTap for fn key detection
  ✓ CGEvent.post for Cmd+V simulation
  ✓ AX APIs for permission checking

Conclusion: App Sandbox INCOMPATIBLE with core features
Result: Non-sandboxed app (no Mac App Store distribution)
```

**Entitlements:**
```xml
<!-- Loqui.entitlements -->
<key>com.apple.security.device.audio-input</key>
<true/>

<key>com.apple.security.automation.apple-events</key>
<true/>

<key>com.apple.security.network.client</key>
<true/>

<!-- NO App Sandbox -->
```

### Privacy Model

**Data Flow:**

```
Audio Capture → Local Processing → Cloud API → Local Insertion
    ↓                  ↓                  ↓            ↓
Microphone      Whisper Model      LLM Cleanup   Clipboard
(hardware)      (on-device)        (cloud)       (local)

LEAVES DEVICE:
  ✓ Transcribed text (sent to Groq/OpenAI for cleanup)
  ✗ Raw audio (stays on device, processed by WhisperKit)
  ✗ User recordings (not stored anywhere)

STORED:
  ✗ Audio recordings (deleted after transcription)
  ✗ Transcribed text (only in clipboard, not persisted)
  ✓ API keys (stored in UserDefaults, used for API auth)
  ✓ Logs (stored in ~/Library/Application Support/Loqui/logs/)
```

**What's Sent to Cloud APIs:**
- Transcribed text only (output of Whisper)
- System prompt (hardcoded, no PII)
- API key (authentication header)

**What's NOT Sent:**
- Raw audio data
- User identity
- Usage analytics
- Telemetry

---

## Code Structure

### File Organization

```
Loqui/
├── Core/
│   ├── AppState.swift          # Central state machine & pipeline orchestrator
│   ├── LoquiLogger.swift       # File-based logging system
│   └── PermissionManager.swift # Permission helpers (deprecated after v1.0)
│
├── Input/
│   ├── FnKeyMonitor.swift      # CGEventTap for fn key detection
│   └── TextInserter.swift      # Clipboard + Cmd+V simulation
│
├── Audio/
│   ├── WhisperAudioCapture.swift # AVAudioEngine wrapper with format conversion
│   └── VADProcessor.swift        # Voice activity detection (stub)
│
├── Transcription/
│   └── TranscriptionEngine.swift # WhisperKit wrapper with pre-loading
│
├── LLM/
│   ├── GroqClient.swift        # Groq API client (primary)
│   ├── OpenAIClient.swift      # OpenAI API client (fallback)
│   └── LLMError.swift          # Error types for LLM operations
│
├── UI/
│   ├── MenuBar/
│   │   ├── MenuBarIconView.swift      # State-based icon with animations
│   │   └── MenuBarContentView.swift   # Dropdown menu
│   ├── Windows/
│   │   ├── HUDWindowController.swift  # Recording timer HUD
│   │   ├── HUDContentView.swift       # Timer display with waveform
│   │   ├── AboutWindow.swift          # About dialog
│   │   ├── PermissionsView.swift      # Manage Permissions window
│   │   └── HUDViewModel.swift         # HUD state management
│   └── Components/
│       ├── VisualEffectView.swift     # NSVisualEffectView wrapper
│       └── ColorExtensions.swift      # Color utilities
│
├── Utilities/
│   └── Notifications.swift     # NotificationCenter extension
│
├── Settings/
│   └── SettingsView.swift      # API key configuration
│
├── LoquiApp.swift              # App entry point & scene configuration
├── AppDelegate.swift           # App lifecycle & initialization
└── Loqui.entitlements          # App permissions & capabilities
```

### Key Design Patterns

**Singleton Pattern:**
```swift
// AppState.swift
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    private init() { }
}
```
- Ensures single source of truth
- `@MainActor` for UI thread safety
- All state mutations on main thread

**Callback Pattern (Audio):**
```swift
// WhisperAudioCapture.swift
var onAudioChunk: ((Data) -> Void)?

audioCapture.onAudioChunk = { chunk in
    self.audioBuffer.append(chunk)
}
```
- Real-time audio streaming
- Avoids blocking the audio thread

**Async/Await (Pipeline):**
```swift
// AppState.swift
private func processRecording() async {
    let trimmed = await vadProcessor.process(audioBuffer)
    let raw = try await transcriptionEngine.transcribe(trimmed)
    let clean = try await groqClient.cleanTranscript(raw)
    try textInserter.insertText(clean)
}
```
- Sequential async operations
- Clean error propagation
- Structured concurrency

**Notification Pattern (fn Key):**
```swift
// FnKeyMonitor.swift
NotificationCenter.default.post(name: .fnKeyPressed, object: nil)

// AppState.swift
NotificationCenter.default.addObserver(forName: .fnKeyPressed) { _ in
    self.startRecording()
}
```
- Decouples fn key detection from app logic
- Global event bus for keyboard events

---

## Build & Development

### Dependencies (SPM)

**Declared in Xcode project:**
```swift
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
]
```

**Automatically resolved:**
- WhisperKit → swift-transformers → swift-argument-parser
- WhisperKit → tokenizers → swift-collections
- No MLX dependencies (removed in v1.0)

### Build Commands

```bash
# Debug build
xcodebuild -project Loqui.xcodeproj -scheme Loqui -configuration Debug build

# Release build (ad-hoc signed)
./scripts/build-release.sh 1.0

# Output: build/Release/Loqui-v1.0.dmg + SHA256
```

### Running from Xcode

**Common Issues:**

**1. "Input Monitoring permission denied"**
- Add Xcode to System Settings → Privacy & Security → Input Monitoring
- Restart Xcode

**2. "Microphone permission denied"**
- Grant permission when prompted
- Or: System Settings → Privacy & Security → Microphone → Loqui

**3. "Whisper model download timeout"**
- First run downloads 594MB (distil-large-v3)
- May take 2-5 minutes on slow connections
- Check logs: `~/Library/Application Support/Loqui/logs/loqui.log`

---

## Troubleshooting

### Logs

**Location:**
```
~/Library/Application Support/Loqui/logs/loqui.log
```

**View real-time:**
```bash
tail -f ~/Library/Application\ Support/Loqui/logs/loqui.log
```

**Log format:**
```
[2026-01-09 14:32:15] 🎤 FnKeyMonitor: fn key PRESSED
[2026-01-09 14:32:18] 🎤 FnKeyMonitor: fn key RELEASED
[2026-01-09 14:32:18] 📊 AppState: Audio buffer size: 48000 bytes
[2026-01-09 14:32:21] 🎯 TranscriptionEngine: Transcribed: "This is a test"
[2026-01-09 14:32:21] ✅ GroqClient: Cleaned text: "This is a test."
[2026-01-09 14:32:21] 📝 TextInserter: Inserting 'This is a test.'
```

### Common Issues

**"App won't start fn key monitoring"**
- Check Input Monitoring permission
- Restart app after granting permission
- If persists: killall Loqui && open /Applications/Loqui.app

**"Transcription returns empty text"**
- Check API keys in Settings (Cmd+,)
- Verify network connection
- Check logs for LLM errors

**"Text not inserting"**
- Check Accessibility permission
- Try manual paste (Cmd+V) - if clipboard has text, permission issue
- Restart app after granting Accessibility

**"Whisper model loading takes 130s"**
- First transcription only
- Pre-loading should prevent this (check logs for "Transcribing silence")
- If still slow: delete `~/Library/Caches/huggingface/` and relaunch

---

## Performance Optimization History

### v0.x → v1.0 Migration

**Problem:** On-device Qwen3-4B LLM was 85-93% of total latency

```
BEFORE (On-Device LLM):
┌─────────────────────────────────────────────────────────┐
│                   Pipeline Latency                       │
├─────────────────────────────────────────────────────────┤
│ VAD:           0.01s ▏                                   │
│ Whisper:       3.10s ████████████                        │
│ Qwen (LLM):   19.68s ████████████████████████████████████│
│ Insertion:     0.02s ▏                                   │
│ TOTAL:        22.81s                                     │
└─────────────────────────────────────────────────────────┘

AFTER (Cloud APIs):
┌─────────────────────────────────────────────────────────┐
│                   Pipeline Latency                       │
├─────────────────────────────────────────────────────────┤
│ VAD:           0.01s ▏                                   │
│ Whisper:       3.10s ████████████████████████████████████│
│ Groq (LLM):    0.28s ▊                                   │
│ Insertion:     0.02s ▏                                   │
│ TOTAL:         3.41s                                     │
└─────────────────────────────────────────────────────────┘

IMPROVEMENT: 19.4s faster (85% reduction)
```

**Changes:**
1. Removed MLX dependencies (~5GB)
2. Removed on-device Qwen3-4B model
3. Added GroqClient (Llama 3.1 70B)
4. Added OpenAIClient (GPT-4o-mini fallback)
5. App size: 6GB → 600MB (90% reduction)

**Trade-offs:**
- ✓ 85% latency reduction
- ✓ 90% app size reduction
- ✓ No model download wait on first launch
- ✗ Requires internet connection for LLM cleanup
- ✗ Requires API keys (free tier available)
- ✗ Transcribed text sent to cloud (not raw audio)

---

## Future Improvements

### Planned (v1.1)

- [ ] Custom hotkey support (beyond fn)
- [ ] Multiple language support (Spanish, French, etc.)
- [ ] Clipboard restoration after insertion
- [ ] Real VAD implementation (Silero VAD)
- [ ] Streaming transcription (real-time display)

### Considered (v2.0+)

- [ ] Offline LLM mode (small local model as fallback)
- [ ] Custom wake word detection
- [ ] Speaker diarization (multi-speaker transcription)
- [ ] Punctuation model (separate from LLM)
- [ ] Custom vocabulary/domain terms
- [ ] Export transcription history

---

## License

**Proprietary License** — Copyright © 2026 Arindam Roy. All rights reserved.

This software is available for **personal, non-commercial use only**. Source code is provided for transparency and educational purposes.

For commercial licensing: arindamroynitw@gmail.com

### Third-Party Licenses

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) — MIT License
- [IBM Plex Sans](https://github.com/IBM/plex) — SIL Open Font License 1.1

---

## Credits

**Made by Arindam Roy**

- Twitter/X: [@crosschainyoda](https://x.com/crosschainyoda)
- LinkedIn: [arindamroynitw](https://www.linkedin.com/in/arindamroynitw/)
- GitHub: [@arindamroynitw](https://github.com/arindamroynitw)

### Technologies

- **WhisperKit** by Argmax — On-device speech recognition
- **Groq** — Ultra-fast LLM inference
- **OpenAI** — GPT-4o-mini fallback
- **IBM Plex Sans** — Typography
- **SwiftUI** — Native macOS UI framework

### Development

- **Claude Code** — Development assistance
- **Open-source community** — Tools and libraries

---

## Contributing

Loqui is currently **closed-source** under a proprietary license. The repository is public for transparency, but contributions are not accepted at this time.

For bug reports and feature requests: [GitHub Issues](https://github.com/arindamroynitw/loqui/issues)

---

## Support

- **Issues:** [GitHub Issues](https://github.com/arindamroynitw/loqui/issues)
- **Email:** arindamroynitw@gmail.com
- **Twitter/X:** [@crosschainyoda](https://x.com/crosschainyoda)

---

<div align="center">

**Loqui** — Fast Speech-to-Text for macOS

Made with ❤️ by Arindam Roy

[Download](https://github.com/arindamroynitw/loqui/releases) | [Website](https://arindamroynitw.github.io/loqui/) | [Report Issue](https://github.com/arindamroynitw/loqui/issues)

</div>
