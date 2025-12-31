//
//  TranscriptionEngine.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Foundation
import WhisperKit

/// Whisper-based transcription engine
class TranscriptionEngine {
    private var whisperKit: WhisperKit?

    /// Initialize the transcription engine with the specified model
    func initialize() async throws {
        print("📦 TranscriptionEngine: Initializing WhisperKit...")

        whisperKit = try await WhisperKit(
            WhisperKitConfig(
                model: "distil-large-v3",
                downloadBase: nil,  // Use default WhisperKit model repository
                useBackgroundDownloadSession: false
            )
        )

        print("✅ TranscriptionEngine: WhisperKit initialized with distil-large-v3")
    }

    /// Transcribe audio data to text
    /// - Parameter audioData: 16kHz, 16-bit mono PCM audio
    /// - Returns: Transcribed text
    func transcribe(_ audioData: Data) async throws -> String {
        print("🎯 TranscriptionEngine: Transcribing \(audioData.count) bytes...")

        guard let whisperKit = whisperKit else {
            throw TranscriptionError.notInitialized
        }

        // Convert Data (Int16) to [Float] normalized to -1.0 to 1.0
        let floatSamples = audioData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Float] in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            return int16Ptr.map { Float($0) / 32768.0 }
        }

        print("🎯 TranscriptionEngine: Converted to \(floatSamples.count) float samples")

        let options = DecodingOptions(
            task: .transcribe,
            language: "en",
            temperature: 0.0,  // Deterministic output
            usePrefillCache: true,  // Speed optimization
            skipSpecialTokens: true,
            wordTimestamps: false  // Not needed for text insertion
        )

        // Create transcription task with timeout
        let transcriptionTask = Task {
            return try await whisperKit.transcribe(
                audioArray: floatSamples,
                decodeOptions: options
            )
        }

        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 180_000_000_000)  // 180 seconds (3 minutes)
            transcriptionTask.cancel()
        }

        do {
            let results = try await transcriptionTask.value
            timeoutTask.cancel()

            // Combine all transcription segments into final text
            let combinedText = results.map { $0.text }.joined(separator: " ")

            guard !combinedText.isEmpty else {
                throw TranscriptionError.emptyResult
            }

            let trimmedText = combinedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            print("✅ TranscriptionEngine: '\(trimmedText)'")
            return trimmedText

        } catch {
            if transcriptionTask.isCancelled {
                throw TranscriptionError.timeout
            }
            throw TranscriptionError.failed(error)
        }
    }
}
