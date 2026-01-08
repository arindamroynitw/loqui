# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Loqui** is a macOS menu bar application for speech-to-text transcription with LLM-based cleanup. Users press and hold the fn key to record, release to transcribe, and text is automatically inserted into the active application.

**Target:** macOS 14.0+ (Apple Silicon optimized)
**Bundle ID:** `com.arindamroy.Loqui`

## Build & Run

### Building the Project
```bash
# Open in Xcode
open Loqui.xcodeproj

# Build from command line
xcodebuild -project Loqui.xcodeproj -scheme Loqui -configuration Debug build

# Run from Xcode: Cmd+R
```

### Required Permissions
The app requires three macOS permissions (requested at runtime):
1. **Microphone** - Audio capture
2. **Input Monitoring** - fn key detection via CGEventTap
3. **Accessibility** - Text insertion via simulated Cmd+V

### Dependencies (Swift Package Manager)
- **WhisperKit** (`argmaxinc/WhisperKit`) - On-device speech recognition (distil-large-v3 model, 594MB)

**Note:** Cloud-based LLM cleanup uses Groq API (Llama 3.1 70B) as primary and OpenAI API (GPT-4o-mini) as fallback via direct HTTP requests (no SDK dependencies).

## Architecture

### Core State Machine: `AppState.swift`

**Central orchestrator** for the entire pipeline. Singleton pattern, `@MainActor` for UI thread safety.

**State Flow:**
```
.idle → .recording(startTime) → .processing → .idle
                                      ↓
                                  .error(Error) → (auto-recover after 2s) → .idle
```

**Pipeline Sequence:**
```swift
fn key press → startRecording()
  ↓ Initialize audio capture
  ↓ Show HUD window with timer
fn key release → stopRecording()
  ↓ Hide HUD
  ↓ processRecording() async:
      1. VAD analysis (silence trimming)
      2. Whisper transcription (~3s)
      3. LLM cleanup (currently 20-40s, will be <1s with cloud APIs)
      4. TextInserter.insertText() (clipboard + Cmd+V)
  ↓ Return to .idle
```

**Key Properties:**
- `fnKeyMonitor` - Global fn key detection
- `audioCapture` - AVAudioEngine wrapper (48kHz → 16kHz mono PCM)
- `transcriptionEngine` - WhisperKit wrapper
- `groqClient` - Primary LLM cleanup (Llama 3.1 70B, ~300ms)
- `openaiClient` - Fallback LLM cleanup (GPT-4o-mini, ~500ms)
- `textInserter` - Clipboard + keyboard event simulation
- `hudWindow` - Floating timer display

### Audio Pipeline

**WhisperAudioCapture.swift:**
- Uses AVAudioEngine with 4096-sample buffer
- **Critical:** Converts input format (44.1/48kHz stereo float32) → 16kHz mono Int16 PCM
- Format conversion happens in `processBuffer()` via AVAudioConverter
- Callback pattern: `onAudioChunk: ((Data) -> Void)?`

**VADProcessor.swift:**
- Currently a stub (returns all audio as speech)
- Designed for FluidAudio Silero VAD integration (threshold 0.75)
- Returns `.noSpeech` or `.speech(Data)` with trimmed audio

### Transcription

**TranscriptionEngine.swift:**
- WhisperKit wrapper for distil-large-v3 model (594MB)
- **Model pre-loading:** Transcribes 0.1s of silence on init to avoid 130s lazy-load delay
- Converts `Data` (Int16) → `[Float]` normalized to [-1.0, 1.0]
- 180-second timeout (handles first-run model loading)
- DecodingOptions: English, temperature 0.0, prefill cache enabled

**Key Implementation Detail:**
WhisperKit returns `[TranscriptionResult]` array. Must map to `.text` and join segments:
```swift
let results = try await whisperKit.transcribe(...)
let text = results.map { $0.text }.joined(separator: " ")
```

### LLM Cleanup (Cloud API)

**GroqClient.swift:**
- Primary provider using Groq API
- Model: Llama 3.1 70B Versatile
- Latency: ~300ms average
- System prompt optimized for transcription cleanup
- Removes fillers ("um", "uh", "like"), fixes grammar, resolves self-corrections
- Direct HTTP requests via URLSession

**OpenAIClient.swift:**
- Fallback provider using OpenAI API
- Model: GPT-4o-mini
- Latency: ~500ms average
- Identical system prompt to Groq for consistency
- Used when Groq fails or API key not configured

**LLM Routing Logic (in AppState.swift):**
1. Try Groq first if API key configured
2. On Groq failure, automatically fallback to OpenAI
3. If both fail or no API keys, return raw Whisper output
4. No retry logic - fail fast and fallback immediately

### Text Insertion

**TextInserter.swift:**
- **Method:** Clipboard + simulated Cmd+V (maximum app compatibility)
- Requires Accessibility permission (`AXIsProcessTrusted()`)
- CGEvent simulation with `.maskCommand` flag
- Virtual key code for 'V': `0x09`
- **Does NOT restore previous clipboard** (design decision for simplicity)

### UI Components

**HUD System:**
- `HUDWindowController.swift` - Borderless floating window at center-bottom
- `HUDContentView.swift` - Timer (MM:SS.T format) + waveform icon with pulse effect
- Fade animations: 0.2s in/out
- Updates every 0.1s for smooth timer display

**Menu Bar:**
- `MenuBarIconView.swift` - Custom Flow logo (18pt) with state-based color changes
  - Uses `Image("MenuBarIcon")` from Assets.xcassets (template rendering)
  - Fixed size: `.frame(width: 18, height: 18)` prevents scaling issues
  - Colors by state: gray (idle), red (recording), blue (processing), orange (error)
  - Animations: `.pulse.byLayer` (recording, macOS 14+), `.rotate` (processing, macOS 15+)
  - Fallback manual animations for older macOS versions
- `MenuBarContentView.swift` - Dropdown menu (Status, Settings, About, Quit)
  - Shows clean status only (no technical model names)
  - `.buttonStyle(.plain)` removes default button borders
  - Styled separators with `.padding(.horizontal, 8).padding(.vertical, 4)`
  - Menu items have `.padding(.leading, 12).padding(.vertical, 4)` for spacing
  - Settings uses `@Environment(\.openSettings)` with `NSApp.activate(ignoringOtherApps: true)` to appear in foreground
- `Assets.xcassets/MenuBarIcon.imageset/` - 18pt Flow "L" logo
  - PDF vector asset with "template" rendering intent (auto-adapts to light/dark mode)
  - Preserves vector representation for all scales
- App uses `.accessory` activation policy (no Dock icon, menu bar only)

**Permission Wizard:**
- `PermissionWizardView.swift` - First-launch setup flow
- `PermissionManager.swift` - Checks and requests Microphone/Accessibility

## Critical Implementation Notes

### fn Key Detection
- Uses CGEventTap with `.flagsChanged` event type
- `.listenOnly` option for non-sandboxed compatibility
- Flag check: `event.flags.contains(.maskSecondaryFn)`
- Posts notifications: `.fnKeyPressed` / `.fnKeyReleased`
- **Must use `fileprivate`** for `previousFnState` (callback access requirement)

### Audio Format Conversion Gotcha
- Input format varies (44.1kHz or 48kHz, stereo, float32)
- WhisperKit requires: 16kHz, mono, Int16 PCM
- **Removed EQ unit** to fix AVAudioEngine error -10868
- Use `AVAudioConverter` directly without additional processing

### Whisper Model Loading
- First transcription triggers lazy-load (~130s)
- **Solution:** Pre-load by transcribing 0.1s silence in `initialize()`
- Model weights cached by WhisperKit after first load

### LLM Output Parsing
- Qwen models include `<think>...</think>` reasoning
- **Must extract text after `</think>` tag**
- Use `.range(of: "</think>")` and substring from `upperBound`

### Error Recovery
- All errors in `processRecording()` auto-recover to `.idle` after 2s delay
- Prevents app getting stuck in error state
- Critical for user experience (can immediately retry)

## Performance Profiling

**Timing logs are instrumented** in `AppState.processRecording()`:
```
⏱️  [0.00s] Pipeline started
⏱️  [0.00s] VAD complete (0.00s)
⏱️  [0.00s] Whisper transcription started
⏱️  [3.10s] Whisper complete (3.10s)
⏱️  [3.10s] LLM cleanup started (Groq)
⏱️  [3.38s] LLM complete (0.28s)
⏱️  [3.40s] Text insertion complete (0.02s)
⏱️  ⏱️  ⏱️  TOTAL PIPELINE LATENCY: 3.40s
```

**Current Performance (v1.0 with Cloud APIs):**
- VAD: <0.01s
- Whisper: ~3.0s (on-device transcription)
- LLM (Groq): ~0.3s (cloud API)
- LLM (OpenAI fallback): ~0.5s (cloud API)
- Text insertion: <0.1s
- **Total**: ~3.5s average

**Performance Improvement:**
- Before (on-device Qwen3-4B): 23-43s total
- After (cloud APIs): ~3.5s total
- **Reduction: 85-92%** (20-40s → 0.3-0.5s for LLM stage)

## Non-Sandboxed Architecture

**Entitlements (Loqui.entitlements):**
```xml
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.automation.apple-events</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

**NO App Sandbox** - Required for:
- CGEventTap (fn key monitoring)
- Accessibility permission (text insertion)
- This means **no Mac App Store distribution**

## Logging & Debugging

**LoquiLogger.swift:**
- Writes to: `~/Library/Application Support/Loqui/logs/loqui.log`
- Use for error tracking and debugging
- Check logs with: `tail -f ~/Library/Application\ Support/Loqui/logs/loqui.log`

**Console Logging:**
- Pipeline stages prefixed with emojis: 🎤 📊 🎯 ✅ ❌
- Critical errors logged with context via `LoquiLogger.shared.logError(error, context: "...")`

## Known Issues & Warnings (Non-Blocking)

1. **AVAudioEngine throwing -10877** during cleanup - Harmless, ignore
2. **HALC_ProxyIOContext overload** on startup - Single cycle skip, doesn't affect capture
3. **WhisperKit fopen cache errors** on first run - Cache initialization, model loads fine
4. **MLX Metal shader compilation warnings** - Normal for MLX, doesn't affect performance

## Git Workflow

**Current commit style** (from git log):
- Detailed commit messages with bullet points
- Emoji: 🤖 for Claude Code attribution
- Co-authored-by: Claude Sonnet 4.5
- Include testing results and known issues
- Reference phases (Phase 1-5 implementation plan)

**Example:**
```
Implement Phase 5: Text insertion, HUD, and error recovery - COMPLETE

Phase 5: Text Insertion & Polish - CORE COMPLETE
- ✅ TextInserter.swift created with clipboard + Cmd+V method
- ✅ HUD window with animated timer (MM:SS.T format)
...

Testing Results:
✅ Test 1: "This is a test transcription." → Inserted
...

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

## On-Demand Permission System (v1.0)

**Simplified Approach:** Permissions requested when needed, no wizard UI

**Permission Flow:**
1. **App Launch** - Starts fn key monitoring (may show Input Monitoring system prompt)
2. **First fn key press** - Requests Microphone permission if not granted
3. **Text insertion** - Requests Accessibility permission if not granted

**Implementation:**
- `AppState.startRecording()` - Checks and requests microphone via `AVCaptureDevice.requestAccess`
- `TextInserter.insertText()` - Checks and requests accessibility via `AXIsProcessTrustedWithOptions`
- `FnKeyMonitor.start()` - Input Monitoring requested automatically via `CGRequestListenEventAccess`

**Manage Permissions Window:**
- Menu bar → "Manage Permissions" - Simple window with buttons to open System Settings
- 3 permission rows: Microphone, Input Monitoring, Accessibility
- Each row has "Open Settings" button - no status checking, no validation

## State Machine Constraints

**Important Rules:**
- Only ONE state can be `in_progress` at a time in state transitions
- `startRecording()` blocks if not `.idle` (prevents concurrent recordings)
- `processRecording()` must ALWAYS return to `.idle` (even on error)
- Error state auto-recovers after 2s (user can retry immediately)

## Symbol Effects & macOS Version Guards

MenuBarIconView uses custom Flow logo with symbol effects applied via `EffectModifier`:
```swift
// Custom image with state-based effects
Image("MenuBarIcon")
    .renderingMode(.template)
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 18, height: 18)
    .foregroundColor(colorForState)
    .modifier(EffectModifier(state: state))
```

**EffectModifier implementation:**
- `.pulse.byLayer` for recording (macOS 14+) with manual fallback (scale + opacity animation)
- `.rotate` for processing (macOS 15+) with manual fallback (rotation animation)
- Symbol effects work on custom images when applied as view modifiers
- Fallback animations use `@State` variables with `.onAppear` triggers

**Note:** Symbol effects (`.pulse`, `.rotate`) require macOS 14+/15+ respectively. The app includes manual animation fallbacks for older versions, maintaining visual consistency across macOS 13+.
