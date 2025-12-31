# Loqui Latency Improvements Specification
**Version:** 1.0
**Date:** 2025-12-31
**Goal:** Reduce pipeline latency from 23-43s → ~3.5s by replacing on-device LLM with cloud APIs

---

## Executive Summary

**Current State:**
- Total latency: 23-43 seconds
- Bottleneck: On-device Qwen3-4B-4bit LLM (20-40s for cleanup)
- Whisper transcription: ~3s (acceptable)

**Target State:**
- Total latency: ~3.5 seconds
- Whisper: ~3s (unchanged)
- Cloud LLM cleanup: ~0.3-0.5s
- Overhead: ~0.2s

**Approach:** Replace on-device LLM with cloud-based API calls (Groq + OpenAI fallback)

---

## Architecture Changes

### Remove
- ✅ Delete `Transcription/SpeechCleaner.swift` (Qwen3-4B integration)
- ✅ Remove all MLX Swift dependencies (`mlx-swift`, `mlx-swift-lm`, `MLXLLM`, `MLXLMCommon`)
- ✅ Remove LLM initialization from `AppState.initializeModels()`
- ✅ Update deployment target from macOS 14.0 → macOS 13.0 (no longer need MLXLLM)

### Add
- ✅ Create `LLM/GroqClient.swift` - API client for Groq inference
- ✅ Create `LLM/OpenAIClient.swift` - Fallback API client
- ✅ Create `LLM/LLMRouter.swift` - Provider selection and failover logic
- ✅ Create `LLM/LLMError.swift` - Error types for API failures
- ✅ Create `UI/Windows/ErrorOverlayView.swift` - Minimal error notification
- ✅ Update `AppState.swift` - Integrate cloud LLM cleanup
- ✅ Update Settings UI - Add API key configuration

---

## Provider Strategy

### Primary Provider: Groq
**Model:** Llama 3.1 70B Versatile
**Endpoint:** `https://api.groq.com/openai/v1/chat/completions`
**Latency:** ~300ms (p50), ~500ms (p99)
**Cost:** Free tier - 14,500 requests/day (RPD limit)
**Rationale:** Fastest inference, excellent quality, generous free tier

### Secondary Provider: OpenAI
**Model:** GPT-4o-mini
**Endpoint:** `https://api.openai.com/v1/chat/completions`
**Latency:** ~500ms average
**Cost:** $0.15/1M input tokens, $0.60/1M output tokens (~$0.00001 per transcription)
**Rationale:** Most reliable fallback, widely trusted, good quality

### Provider Selection Logic

**Priority Order:**
1. **Groq** (always attempted first)
2. **OpenAI** (fallback only)

**Routing Rules:**
- Track last 3 requests per provider
- Switch from Groq → OpenAI if:
  - 3 consecutive failures, OR
  - 3 consecutive requests >1000ms latency
- Once switched, stay on OpenAI for entire session
- Reset to Groq on app restart

**Fallback Behavior:**
- **Silent automatic fallback** - no user notification during switch
- If Groq fails/slow → immediately try OpenAI
- If both fail → insert raw Whisper text + show error overlay

---

## Error Handling

### API Failure Scenarios

| Scenario | Behavior | User Experience |
|----------|----------|-----------------|
| Groq timeout (>5s) | Try OpenAI immediately | Seamless, slight latency increase |
| Groq rate limited | Try OpenAI immediately | Seamless |
| Groq returns error | Try OpenAI immediately | Seamless |
| Both providers fail | Insert raw Whisper text | Error overlay appears |
| No network | Insert raw Whisper text | Error overlay: "Cleanup failed" |
| Invalid API keys | Insert raw Whisper text | Error overlay appears |

### Error Overlay

**Design:**
- Small, minimal overlay near HUD position (center-bottom)
- Red warning icon + "Cleanup failed" text
- Fades in 0.2s, stays 3s, fades out 0.2s
- No interaction required (auto-dismiss)
- Does NOT block text insertion workflow

**Implementation:**
```swift
struct ErrorOverlayView: View {
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text("Cleanup failed")
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeIn(duration: 0.2)) { isVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.2)) { isVisible = false }
            }
        }
    }
}
```

### Timeout Configuration
- **Per-request timeout:** 5 seconds
- **Rationale:** Balances patience for slow networks vs failing fast
- **On timeout:** Counts as failure, triggers fallback

---

## LLM Cleanup Implementation

### Cleanup Prompt (Fixed)

```
You are a transcript cleanup assistant. Your ONLY job is to clean up speech-to-text transcriptions.

Rules:
1. Remove filler words: um, uh, like, you know, yeah (when repeated)
2. Fix obvious grammar mistakes
3. Resolve self-corrections (e.g., "monday no tuesday" → "tuesday")
4. Preserve the speaker's exact meaning and tone
5. Do NOT add new information or elaborate
6. Do NOT change punctuation if it alters meaning
7. Keep output concise

Output ONLY the cleaned text. No explanations, no thinking, no preamble.
```

**Rationale:**
- Fixed prompt ensures consistency
- No user customization (simpler UX, prevents bad prompts)
- Optimized through testing

### API Request Format

**Groq Request:**
```json
{
  "model": "llama-3.1-70b-versatile",
  "messages": [
    {"role": "system", "content": "<cleanup prompt>"},
    {"role": "user", "content": "Clean this transcription: <raw_text>"}
  ],
  "temperature": 0.3,
  "max_tokens": 100,
  "top_p": 1.0
}
```

**OpenAI Request:**
```json
{
  "model": "gpt-4o-mini",
  "messages": [
    {"role": "system", "content": "<cleanup prompt>"},
    {"role": "user", "content": "Clean this transcription: <raw_text>"}
  ],
  "temperature": 0.3,
  "max_tokens": 100
}
```

### Long Transcription Handling
- **No special handling** for long transcriptions (>100 words)
- Same cleanup process regardless of length
- Latency scales linearly with input length
- Rationale: Simplicity, quality consistency

---

## Settings UI

### Structure
**Single Tab:** "LLM Providers"

**Layout:**
```
┌─────────────────────────────────────────┐
│  LLM Providers                          │
├─────────────────────────────────────────┤
│                                         │
│  Primary Provider: Groq                 │
│  ┌──────────────────────────────────┐  │
│  │ API Key: ************************ │  │
│  └──────────────────────────────────┘  │
│  [Get Groq API Key →]                   │
│                                         │
│  Fallback Provider: OpenAI              │
│  ┌──────────────────────────────────┐  │
│  │ API Key: ************************ │  │
│  └──────────────────────────────────┘  │
│  [Get OpenAI API Key →]                 │
│                                         │
│  ⚠️ Changes require app restart          │
│                                         │
│            [Save]  [Cancel]             │
└─────────────────────────────────────────┘
```

**Fields:**
- Groq API Key (text field, password style)
- OpenAI API Key (text field, password style)
- "Get API Key" links open browser to signup pages

**Storage:**
- Keys stored in `UserDefaults`
- Keys: `groqAPIKey`, `openaiAPIKey`
- Not encrypted (acceptable per user preference)

**Behavior:**
- Changes saved to UserDefaults immediately
- Requires app restart to take effect (simplest implementation)
- No validation during entry (validated on first API call)

### First Launch Experience

**On First Transcription Attempt (No Keys Configured):**
1. Detect no API keys in UserDefaults
2. Show Settings window automatically
3. Block transcription until at least Groq key entered
4. User enters Groq key, clicks Save
5. Restart app manually
6. Transcription now works with Groq

**Settings Window Trigger:**
```swift
func startRecording() {
    // Check if keys configured
    if !hasValidAPIKeys() {
        showSettingsWindow()
        return  // Block recording
    }
    // ... normal recording flow
}
```

---

## Implementation Details

### LLMRouter.swift

**Responsibilities:**
- Track provider performance (last 3 requests)
- Select provider based on routing rules
- Handle failover logic
- Manage timeout enforcement

**State Tracking:**
```swift
@MainActor
class LLMRouter {
    enum Provider { case groq, openai }

    private var currentProvider: Provider = .groq
    private var groqHistory: [RequestResult] = []  // Last 3
    private var openaiHistory: [RequestResult] = []

    struct RequestResult {
        let success: Bool
        let latency: TimeInterval
        let timestamp: Date
    }

    func selectProvider() -> Provider {
        // Always try Groq first unless switched due to failures
        return currentProvider
    }

    func recordResult(_ provider: Provider, success: Bool, latency: TimeInterval) {
        // Track result, evaluate routing rules
        if shouldSwitch(from: provider) {
            switchToFallback()
        }
    }

    private func shouldSwitch(from provider: Provider) -> Bool {
        guard provider == .groq else { return false }
        let history = groqHistory.suffix(3)

        // 3 consecutive failures
        if history.count == 3 && history.allSatisfy({ !$0.success }) {
            return true
        }

        // 3 consecutive >1s latency
        if history.count == 3 && history.allSatisfy({ $0.latency > 1.0 }) {
            return true
        }

        return false
    }
}
```

### GroqClient.swift

**Implementation:**
```swift
class GroqClient {
    private let apiKey: String
    private let endpoint = "https://api.groq.com/openai/v1/chat/completions"
    private let timeout: TimeInterval = 5.0

    func cleanTranscript(_ rawText: String) async throws -> String {
        let request = makeRequest(rawText)

        // Timeout wrapper
        try await withTimeout(timeout) {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(GroqResponse.self, from: data)
            return response.choices.first?.message.content ?? rawText
        }
    }

    private func makeRequest(_ text: String) -> URLRequest {
        let body: [String: Any] = [
            "model": "llama-3.1-70b-versatile",
            "messages": [
                ["role": "system", "content": cleanupPrompt],
                ["role": "user", "content": "Clean this transcription: \(text)"]
            ],
            "temperature": 0.3,
            "max_tokens": 100
        ]

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try! JSONSerialization.data(withJSONObject: body)
        return request
    }
}
```

### AppState Integration

**Updated processRecording():**
```swift
private func processRecording() async {
    let pipelineStart = Date()

    // ... VAD and Whisper (unchanged) ...

    // LLM cleanup with cloud API
    let llmStart = Date()
    print("⏱️  LLM cleanup started")

    var finalText = rawText
    let provider = router.selectProvider()

    do {
        if provider == .groq {
            finalText = try await groqClient.cleanTranscript(rawText)
        } else {
            finalText = try await openaiClient.cleanTranscript(rawText)
        }

        let latency = Date().timeIntervalSince(llmStart)
        router.recordResult(provider, success: true, latency: latency)
        print("⏱️  LLM complete (\(latency)s)")

    } catch {
        let latency = Date().timeIntervalSince(llmStart)
        router.recordResult(provider, success: false, latency: latency)

        // Try fallback if primary failed
        if provider == .groq {
            finalText = (try? await openaiClient.cleanTranscript(rawText)) ?? rawText
        }

        // Show error overlay if both failed
        if finalText == rawText {
            showErrorOverlay()
        }
    }

    // ... Text insertion (unchanged) ...
}
```

---

## Performance Targets

### Latency Breakdown (Target)

| Stage | Current | Target | Improvement |
|-------|---------|--------|-------------|
| VAD | 0.00s | 0.00s | - |
| Whisper | 3.10s | 3.10s | - |
| **LLM Cleanup** | **20-40s** | **0.30s** | **98% reduction** |
| Text Insertion | 0.08s | 0.08s | - |
| **TOTAL** | **23-43s** | **~3.5s** | **85-92% reduction** |

### Success Metrics

**Acceptable Performance:**
- ✅ p50 latency: <4s
- ✅ p95 latency: <6s
- ✅ p99 latency: <8s

**Quality Metrics:**
- ✅ Filler removal rate: >95%
- ✅ Grammar fix accuracy: >90%
- ✅ Self-correction handling: >85%

**Reliability:**
- ✅ Groq availability: >99.5%
- ✅ OpenAI fallback success: >99.9%
- ✅ Combined uptime: >99.95%

---

## Implementation Phases

### Phase 1: Core Groq Integration (MVP)
**Time Estimate:** 2-3 hours

**Tasks:**
1. Create `LLM/GroqClient.swift`
2. Create `LLM/LLMError.swift`
3. Remove Qwen3-4B code from `AppState.swift`
4. Update `AppState.processRecording()` with Groq cleanup
5. Add basic settings UI for Groq API key
6. Test latency with profiling

**Success Criteria:**
- ✅ Groq cleanup working end-to-end
- ✅ Latency <4s consistently
- ✅ Error handling (show raw text on failure)

### Phase 2: OpenAI Fallback
**Time Estimate:** 1-2 hours

**Tasks:**
1. Create `LLM/OpenAIClient.swift` (similar to Groq)
2. Add OpenAI key field to Settings
3. Update `AppState` to try OpenAI on Groq failure
4. Test fallback behavior

**Success Criteria:**
- ✅ OpenAI fallback working
- ✅ Seamless transition when Groq fails
- ✅ Raw text inserted if both fail

### Phase 3: Smart Routing
**Time Estimate:** 1-2 hours

**Tasks:**
1. Create `LLM/LLMRouter.swift`
2. Implement performance tracking
3. Implement routing rules (3 failures / >1s latency)
4. Update `AppState` to use router
5. Test routing logic

**Success Criteria:**
- ✅ Auto-switches to OpenAI after 3 Groq failures
- ✅ Stays on OpenAI for session after switch
- ✅ Resets to Groq on app restart

### Phase 4: Error Overlay & Polish
**Time Estimate:** 1 hour

**Tasks:**
1. Create `UI/Windows/ErrorOverlayView.swift`
2. Integrate with `AppState` error handling
3. Test error display
4. Final cleanup and testing

**Success Criteria:**
- ✅ Error overlay appears on total failure
- ✅ Auto-dismisses after 3s
- ✅ Doesn't block workflow

**Total Time:** 5-8 hours

---

## Testing Plan

### Unit Tests
- ✅ `GroqClient` request formatting
- ✅ `OpenAIClient` request formatting
- ✅ `LLMRouter` routing logic
- ✅ Timeout handling

### Integration Tests
1. **Happy Path:**
   - Record → Whisper → Groq cleanup → Insert
   - Verify <4s latency
   - Verify cleaned text quality

2. **Groq Failure:**
   - Simulate Groq timeout
   - Verify OpenAI fallback
   - Verify seamless experience

3. **Total Failure:**
   - Disable network
   - Verify raw text insertion
   - Verify error overlay appears

4. **Routing:**
   - Trigger 3 Groq failures
   - Verify switch to OpenAI
   - Verify stays on OpenAI
   - Restart app, verify reset to Groq

5. **Settings:**
   - Enter valid keys, verify save
   - Enter invalid keys, verify API error handling
   - Test app restart requirement

### Performance Validation
- Run 50 transcriptions, measure latency distribution
- Target: p95 <6s, p99 <8s
- Compare Groq vs OpenAI latency
- Verify no memory leaks after 100 transcriptions

---

## Rollback Plan

**If cloud API approach fails to meet latency targets:**

1. Keep Whisper (working well)
2. Implement **regex-based cleanup** as fast alternative:
   - Remove common fillers: `/(um|uh|like|you know)\s*/gi`
   - Remove repeated words: `/\b(\w+)\s+\1\b/gi`
   - Latency: <10ms
   - Quality: Lower than LLM but acceptable

3. Make LLM cleanup **optional toggle** in settings:
   - Default: OFF (regex cleanup, ~3s)
   - Advanced: ON (cloud LLM, ~3.5s)

**Not rolling back to on-device LLM** - 20-40s is unacceptable.

---

## Cost Analysis

### Groq (Primary)
- **Free Tier:** 14,500 requests/day
- **Typical Usage:** 50-100 transcriptions/day
- **Cost:** $0/month (well within free tier)

### OpenAI (Fallback)
- **Pricing:** $0.15/1M input tokens, $0.60/1M output tokens
- **Per Transcription:** ~50 input + 50 output tokens
- **Cost per Request:** ~$0.00001
- **Typical Usage (10% fallback):** 5-10 requests/day
- **Cost:** <$0.01/month

**Total Monthly Cost:** ~$0 (Groq free tier sufficient)

---

## Security Considerations

### API Key Storage
- **Location:** UserDefaults (not encrypted)
- **Risk:** Keys visible to anyone with file system access
- **Mitigation:** User-accepted trade-off for simplicity
- **Future:** Could upgrade to Keychain if needed

### Data Privacy
- **Transcripts sent to cloud:** Yes (Groq, OpenAI)
- **User awareness:** First-launch setup makes this clear
- **Data retention:** Per provider policies (ephemeral for API calls)
- **Acceptable:** User prioritizes speed over on-device privacy

### Network Security
- **HTTPS only:** All API calls over TLS
- **API key transmission:** Bearer token in Authorization header
- **No local caching:** API responses not stored

---

## Dependencies

### Add
- None (pure URLSession-based HTTP clients)

### Remove
- `mlx-swift` (0.7.0+)
- `mlx-swift-lm` (0.7.0+)
- `MLXLLM`
- `MLXLMCommon`

**Result:** Smaller app bundle, simpler dependency tree

---

## Future Enhancements (Not in Scope)

1. **Anthropic Claude support** - If Groq/OpenAI insufficient
2. **Prompt customization** - Power user feature
3. **Usage telemetry** - Track provider performance
4. **Regex-based fast cleanup** - Ultra-low latency option
5. **Streaming responses** - Lower perceived latency
6. **Result caching** - Optimize repeated phrases
7. **Manual retry** - Re-cleanup last transcription
8. **A/B testing framework** - Compare provider quality

---

## Appendix

### Groq API Setup
1. Visit https://console.groq.com
2. Sign up (free, email only)
3. Navigate to API Keys
4. Create new key
5. Copy key to Loqui settings

### OpenAI API Setup
1. Visit https://platform.openai.com
2. Sign up (requires payment method for usage)
3. Navigate to API Keys
4. Create new key
5. Copy key to Loqui settings
6. Add $5-10 credit (sufficient for months)

### Cleanup Prompt Optimization Tips
- Keep system prompt <200 tokens
- Use imperative voice ("Remove", "Fix", not "You should")
- Specify output format explicitly
- Test with edge cases (stuttering, false starts)
- Iterate based on real transcription failures

---

## Sign-off

**Decision:** Proceed with cloud-based LLM cleanup (Groq + OpenAI)

**Rationale:**
- 85-92% latency reduction (23-43s → ~3.5s)
- Maintains cleanup quality
- Acceptable trade-offs (no offline, cloud privacy)
- Negligible cost ($0/month on free tier)
- Aligns with user priorities (speed + quality)

**Next Steps:**
1. Implement Phase 1 (Groq MVP)
2. Validate <4s latency
3. Implement Phase 2-4 (fallback + routing + polish)
4. Production testing
5. Commit to main branch

**Approval:** Ready for implementation ✅
