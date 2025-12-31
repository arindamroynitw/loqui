//
//  VADProcessor.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Foundation

// FluidAudio will be imported once the dependency is added
// import FluidAudio

/// Voice Activity Detection (VAD) to filter silence and trim audio
/// Uses Silero VAD via FluidAudio (CoreML optimized)
class VADProcessor {
    // TODO: Add FluidAudio dependency before uncommenting
    // private let manager: VadManager
    // private var state: VadState?

    /// Initialize VAD with default threshold
    init() async throws {
        print("🎙️ VADProcessor: Initializing...")

        // TODO: Uncomment once FluidAudio is added
        // manager = try await VadManager(config: VadConfig(defaultThreshold: 0.75))
        // print("✅ VADProcessor: Initialized with threshold 0.75")
    }

    /// Analyze recording and trim silence
    /// - Parameter audioData: Raw 16kHz mono PCM audio
    /// - Returns: VADResult with trimmed audio or noSpeech
    func analyzeRecording(_ audioData: Data) async throws -> VADResult {
        print("🎙️ VADProcessor: Analyzing \(audioData.count) bytes of audio...")

        // TODO: Uncomment once FluidAudio is added
        /*
        state = await manager.makeStreamState()

        var hasSpeech = false
        var speechStart: Int?
        var speechEnd: Int?

        // Process in 512-sample chunks (32ms at 16kHz) - required by Silero VAD
        let chunkSize = 512 * 2  // 2 bytes per Int16 sample
        for offset in stride(from: 0, to: audioData.count, by: chunkSize) {
            let end = min(offset + chunkSize, audioData.count)
            let chunk = audioData[offset..<end]

            let result = try await manager.processStreamingChunk(
                chunk,
                state: state!,
                config: .default,
                returnSeconds: true
            )
            state = result.state

            if result.probability > 0.5 {
                hasSpeech = true
                if speechStart == nil {
                    speechStart = offset
                }
                speechEnd = end
            }

            if let event = result.event, event.kind == .speechEnd {
                break
            }
        }

        guard hasSpeech, let start = speechStart, let end = speechEnd else {
            print("❌ VADProcessor: No speech detected")
            return .noSpeech
        }

        // Return trimmed audio (silence removed from start/end)
        let trimmedAudio = audioData[start..<end]
        print("✅ VADProcessor: Speech detected, trimmed to \(trimmedAudio.count) bytes")
        return .speech(Data(trimmedAudio))
        */

        // TEMPORARY: For Phase 2 testing without FluidAudio
        // Always return speech detected with full audio
        if audioData.count > 0 {
            print("✅ VADProcessor: (Stub) Speech detected, using full audio")
            return .speech(audioData)
        } else {
            print("❌ VADProcessor: (Stub) Empty audio buffer")
            return .noSpeech
        }
    }
}

/// VAD analysis result
enum VADResult {
    case noSpeech
    case speech(Data)  // Trimmed audio data
}
