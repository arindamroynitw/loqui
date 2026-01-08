# Loqui

<div align="center">

**Fast Speech-to-Text for macOS**

Press fn → Speak → Instant Transcription

[Download v1.0](https://github.com/arindamroynitw/loqui/releases/download/v1.0/Loqui-v1.0.dmg) | [Website](https://arindamroynitw.github.io/loqui/download.html)

</div>

---

## Overview

Loqui is a native macOS menu bar application that provides instant speech-to-text transcription with AI-powered cleanup. Simply press and hold the fn key to record, release to transcribe, and the text is automatically inserted into your active application.

**Key Features:**
- 🎤 **Instant Recording** - Press fn key anywhere in macOS
- 🧠 **On-Device Transcription** - WhisperKit distil-large-v3 (~3s latency)
- ✨ **AI Cleanup** - Groq/OpenAI removes fillers and fixes grammar
- ⚡ **Universal Insertion** - Works in any text field across all apps
- 🔒 **Privacy-Focused** - Transcription happens on your device
- 🎨 **Native UI** - SwiftUI menu bar app with HUD

---

## Download & Installation

### Download

**[⬇️ Download Loqui-v1.0.dmg](https://github.com/arindamroynitw/loqui/releases/download/v1.0/Loqui-v1.0.dmg)**

Or visit the [download page](https://arindamroynitw.github.io/loqui/download.html).

### System Requirements

- **macOS:** 14.6 (Sonoma) or later
- **Processor:** Apple Silicon (M1/M2/M3/M4) or Intel
- **Memory:** 8 GB RAM minimum
- **Storage:** ~6 GB for models (downloaded on first launch)

### Installation Steps

1. Download `Loqui-v1.0.dmg`
2. Open the DMG file
3. Drag **Loqui.app** to your **Applications** folder
4. Launch Loqui from Applications

### ⚠️ Security Warning (First Launch)

This app is currently **unsigned**. macOS will show a security warning.

**To open the app:**
1. Right-click (or Control-click) on **Loqui.app**
2. Select **"Open"** from the menu
3. Click **"Open"** in the security dialog

*Alternatively:* System Settings → Privacy & Security → "Loqui was blocked" → "Open Anyway"

### 📋 Permission Setup

On first launch, Loqui will guide you through three required permissions:

- **Microphone** - Record your voice for transcription
- **Accessibility** - Insert transcribed text into applications
- **Input Monitoring** - Detect fn key presses

---

## Usage

1. **Launch** - Loqui runs in your menu bar (look for the Flow "L" icon)
2. **Press & Hold** the `fn` key to start recording
3. **Speak** your message (HUD shows recording timer)
4. **Release** the `fn` key to stop recording
5. **Transcription** happens automatically (~3.5s total)
6. **Text inserted** into your active application via clipboard + Cmd+V

### Pipeline Flow

```
fn press → Show HUD → Record audio → fn release → Hide HUD
         ↓
VAD analysis → Whisper transcription (~3s) → LLM cleanup (~0.3-0.5s)
         ↓
Set clipboard → Simulate Cmd+V → Text inserted ✅
```

### Configuration

Click the menu bar icon → **Settings** to configure API keys:

- **Groq API Key** - For Llama 3.1 70B cleanup ([Get free key](https://console.groq.com))
- **OpenAI API Key** - Fallback for GPT-4o-mini ([Get key](https://platform.openai.com/api-keys))

**Note:** At least one API key is required for LLM cleanup functionality.

---

## Build from Source

### Prerequisites

- Xcode 16+ (macOS 14.6+ SDK)
- macOS 14.6 or later

### Steps

```bash
# Clone repository
git clone https://github.com/arindamroynitw/loqui.git
cd loqui

# Open in Xcode
open Loqui.xcodeproj

# Build and run (Cmd+R)
# Or build from command line:
xcodebuild -project Loqui.xcodeproj -scheme Loqui -configuration Debug build
```

### Dependencies (Swift Package Manager)

Dependencies are automatically resolved by Xcode:

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - On-device speech recognition
- [mlx-swift](https://github.com/ml-explore/mlx-swift) - Apple Silicon ML framework (to be removed in v1.1)
- [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) - Language model support (to be removed in v1.1)

### Build Release DMG

```bash
./scripts/build-release.sh 1.0
```

Output: `build/Release/Loqui-v1.0.dmg` + SHA256 checksum

---

## Architecture

### Core Components

**AppState.swift** - Central state machine orchestrating the entire pipeline
```
.idle → .recording(startTime) → .processing → .idle
                                     ↓
                                 .error(Error) → (auto-recover 2s) → .idle
```

**WhisperAudioCapture.swift** - AVAudioEngine wrapper
- Converts 44.1/48kHz stereo → 16kHz mono Int16 PCM
- 4096-sample buffer with real-time format conversion

**TranscriptionEngine.swift** - WhisperKit wrapper
- distil-large-v3 model (594MB)
- Pre-loads model by transcribing 0.1s silence (avoids 130s lazy-load)
- 180-second timeout for first-run model download

**LLMRouter.swift** - Smart API routing with failure tracking
- Primary: Groq (Llama 3.1 70B, ~300ms)
- Fallback: OpenAI (GPT-4o-mini, ~500ms)
- Removes fillers ("um", "uh", "like"), fixes grammar, resolves self-corrections

**TextInserter.swift** - Universal text insertion
- Method: Clipboard + simulated Cmd+V (maximum app compatibility)
- Requires Accessibility permission

**HUD System** - Recording timer display
- Floating window at center-bottom
- Timer format: MM:SS.T
- Fade animations (0.2s)

### Menu Bar UI

- **MenuBarIconView.swift** - Custom Flow logo (18pt) with state-based animations
  - Gray (idle), Red (recording), Blue (processing), Orange (error)
  - Symbol effects: `.pulse` (recording), `.rotate` (processing)
- **MenuBarContentView.swift** - Dropdown menu (Status, Settings, About, Quit)

### Data Flow

```
fn key press → FnKeyMonitor → AppState.startRecording()
             ↓
WhisperAudioCapture starts → Audio buffer callback → Accumulate data
             ↓
fn key release → AppState.stopRecording() → processRecording()
             ↓
VADProcessor (silence trimming) → TranscriptionEngine (Whisper)
             ↓
LLMRouter (Groq/OpenAI cleanup) → TextInserter (clipboard + Cmd+V)
             ↓
AppState returns to .idle
```

---

## Permissions Explained

### Why Each Permission is Needed

**Microphone** (`NSMicrophoneUsageDescription`)
- Required to capture audio for transcription
- Used only when fn key is pressed
- Audio processed on-device with WhisperKit

**Accessibility** (`NSAccessibilityUsageDescription`)
- Required to simulate keyboard events (Cmd+V)
- Enables universal text insertion across all apps
- Only used to paste transcribed text

**Input Monitoring** (via CGEventTap)
- Required to detect fn key press/release globally
- Enables hands-free recording activation
- No other keystrokes are monitored

### Non-Sandboxed Architecture

Loqui runs **without App Sandbox** to enable:
- CGEventTap for fn key monitoring
- Accessibility permission for text insertion

**This prevents Mac App Store distribution** but allows maximum functionality.

---

## Performance

### Typical Latency (v1.0)

| Stage | Duration | Notes |
|-------|----------|-------|
| VAD Analysis | <0.01s | Silence trimming |
| Whisper Transcription | ~3.0s | distil-large-v3 model |
| LLM Cleanup (Groq) | ~0.3s | Llama 3.1 70B |
| LLM Cleanup (OpenAI) | ~0.5s | GPT-4o-mini fallback |
| Text Insertion | <0.1s | Clipboard + Cmd+V |
| **Total Pipeline** | **~3.5s** | fn release → text inserted |

Performance varies based on audio length and network latency.

### Optimization History

- **Before cloud migration:** 23-43s total (on-device Qwen3-4B LLM bottleneck)
- **After cloud migration (v1.0):** ~3.5s total (**85-92% reduction**)

---

## Known Issues

- App is unsigned (security warning on first launch)
- No Mac App Store distribution
- Clipboard overwritten (not restored after insertion)
- First launch downloads ~6 GB models (Whisper 594MB + Qwen ~5GB - Qwen to be removed in v1.1)

---

## Troubleshooting

### App Won't Open
Follow security workaround: Right-click → Open → Open

### Permissions Denied
System Settings → Privacy & Security → Enable Microphone, Accessibility, Input Monitoring for Loqui

### Transcription Fails
- Verify API keys configured in Settings (Groq or OpenAI)
- Check network connection for LLM cleanup

### View Logs
```bash
tail -f ~/Library/Application\ Support/Loqui/logs/loqui.log
```

### Report Issues
[GitHub Issues](https://github.com/arindamroynitw/loqui/issues)

---

## Roadmap

### v1.1 (Planned)

- [ ] Remove MLX dependencies (Qwen3-4B on-device LLM)
- [ ] Reduce app size from ~6 GB to ~600 MB
- [ ] Custom hotkey support (beyond fn key)
- [ ] Multiple language support
- [ ] Clipboard restoration after insertion
- [ ] Code signing for seamless installation

### Future Considerations

- Mac App Store distribution (requires architectural changes)
- Real-time streaming transcription
- Custom wake word detection
- Offline LLM cleanup mode

---

## License

**Proprietary License** - Copyright © 2026 Arindam Roy. All rights reserved.

This software is available for **personal, non-commercial use only**. Source code is provided for transparency and educational purposes. See [LICENSE](LICENSE) for full terms.

For commercial licensing inquiries: arindamroynitw@gmail.com

### Third-Party Licenses

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - MIT License
- [IBM Plex Sans](https://github.com/IBM/plex) - SIL Open Font License 1.1

---

## Credits

**Made by Arindam Roy**
- Twitter/X: [@crosschainyoda](https://x.com/crosschainyoda)
- LinkedIn: [arindamroynitw](https://www.linkedin.com/in/arindamroynitw/)

### Technologies

- **WhisperKit** by Argmax - On-device speech recognition
- **Groq** - Ultra-fast LLM inference
- **OpenAI** - GPT-4o-mini fallback
- **IBM Plex Sans** - Typography
- **Apple MLX** - Apple Silicon ML framework (temporary, v1.0 only)

### Special Thanks

- Claude Code for development assistance
- Open-source community for tools and libraries

---

## Contributing

Loqui is currently **closed-source** under a proprietary license. The repository is public for transparency, but contributions are not accepted at this time.

For bug reports and feature requests, please use [GitHub Issues](https://github.com/arindamroynitw/loqui/issues).

---

## Support

- **Issues:** [GitHub Issues](https://github.com/arindamroynitw/loqui/issues)
- **Email:** arindamroynitw@gmail.com
- **Twitter/X:** [@crosschainyoda](https://x.com/crosschainyoda)

---

<div align="center">

**Loqui** - Fast Speech-to-Text for macOS

Made with ❤️ by Arindam Roy

[Download](https://github.com/arindamroynitw/loqui/releases) | [Website](https://arindamroynitw.github.io/loqui/download.html) | [Report Issue](https://github.com/arindamroynitw/loqui/issues)

</div>
