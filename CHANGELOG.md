# Changelog

All notable changes to Loqui will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-01-02

### Added

**Core Functionality**
- fn key press-to-record with visual HUD timer
- On-device speech recognition using WhisperKit (distil-large-v3 model, 594MB)
- Cloud-based LLM cleanup with Groq (Llama 3.1 70B) and OpenAI (GPT-4o-mini)
- Automatic text insertion via clipboard + Cmd+V simulation
- Universal compatibility across all macOS applications

**User Interface**
- Menu bar app with custom Flow logo (18pt)
- State-based icon animations (.pulse for recording, .rotate for processing)
- Dropdown menu with Status, Settings, About, and Quit options
- HUD window with recording timer (MM:SS.T format) and waveform animation
- SwiftUI-based About window with branded gradient design
- Settings UI for API key configuration (Groq + OpenAI)

**System Integration**
- Permission wizard for first-launch setup (Microphone, Accessibility, Input Monitoring)
- Non-sandboxed architecture for maximum compatibility
- Global fn key monitoring via CGEventTap
- Automatic model downloads on first launch

**Developer Features**
- Comprehensive logging system with file output (`~/Library/Application Support/Loqui/logs/loqui.log`)
- Performance timing instrumentation for all pipeline stages
- Build automation script (`scripts/build-release.sh`)
- DMG creation with SHA256 checksum generation

### Performance

**Latency Breakdown (Typical)**
- VAD analysis: <0.01s
- Whisper transcription: ~3.0s
- LLM cleanup (Groq): ~0.3s
- LLM cleanup (OpenAI fallback): ~0.5s
- Text insertion: <0.1s
- **Total pipeline: ~3.5s** (fn release → text inserted)

**Optimization History**
- Before cloud migration: 23-43s total (on-device Qwen3-4B bottleneck)
- After cloud migration: ~3.5s total (**85-92% latency reduction**)

### Known Issues

- App is unsigned (security warning on first launch - workaround: right-click → Open)
- No Mac App Store distribution (non-sandboxed permissions required)
- Clipboard overwritten and not restored after text insertion
- First launch downloads ~6 GB models (Whisper 594MB + Qwen ~5GB)
  - Note: Qwen on-device LLM is deprecated and will be removed in v1.1
- AVAudioEngine throws harmless -10877 errors during cleanup
- HALC_ProxyIOContext overload warnings on startup (single cycle skip, non-blocking)

### Technical Details

**Models**
- WhisperKit: distil-large-v3 (594MB, ~3s transcription)
- Groq: Llama 3.1 70B (cloud, ~0.3s cleanup)
- OpenAI: GPT-4o-mini (cloud fallback, ~0.5s cleanup)
- Qwen3-4B-4bit (~5GB) - **Deprecated, to be removed in v1.1**

**Requirements**
- macOS 14.6 (Sonoma) or later
- Apple Silicon (M1/M2/M3/M4) or Intel
- 8 GB RAM minimum
- ~6 GB storage for models

**Permissions**
- Microphone - Audio capture for transcription
- Accessibility - Text insertion via Cmd+V simulation
- Input Monitoring - fn key detection globally

---

## [Unreleased]

### Planned for v1.1
- Remove MLX dependencies (Qwen3-4B on-device LLM)
- Reduce app size from ~6 GB to ~600 MB
- Custom hotkey support (beyond fn key)
- Multiple language support
- Clipboard restoration after insertion
- Code signing for seamless installation experience

---

## Release Links

- [1.0.0] - https://github.com/arindamroynitw/loqui/releases/tag/v1.0

---

## Legend

- **Added** - New features
- **Changed** - Changes in existing functionality
- **Deprecated** - Soon-to-be removed features
- **Removed** - Removed features
- **Fixed** - Bug fixes
- **Security** - Vulnerability patches
- **Performance** - Performance improvements
