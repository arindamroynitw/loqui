//
//  SpeechCleaner.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Foundation
import MLXLLM
import MLXLMCommon

/// LLM-based speech transcription cleanup using Qwen3-4B-Instruct-4bit
/// Removes fillers (um, uh), fixes grammar, resolves self-corrections
@MainActor
class SpeechCleaner {
    private var chatSession: ChatSession?
    private let modelID = "mlx-community/Qwen3-4B-4bit"

    // System prompt for cleanup task
    private let systemPrompt = """
    You are a text cleanup assistant. Your ONLY job is to clean up speech-to-text transcriptions.

    Rules:
    1. Remove filler words: um, uh, like, you know, etc.
    2. Fix obvious grammar mistakes
    3. Resolve self-corrections (e.g., "next tuesday no wednesday" → "next wednesday")
    4. Preserve the speaker's meaning and tone
    5. Keep it concise - output ONLY the cleaned text, nothing else
    6. Do NOT add punctuation if it changes meaning
    7. Do NOT elaborate or add extra content

    Output ONLY the cleaned text. No explanations, no quotes, no preamble.
    """

    /// Initialize the LLM model
    func initialize() async throws {
        print("📦 SpeechCleaner: Initializing \(modelID)...")

        do {
            // Load model from HuggingFace
            let model = try await loadModel(id: modelID)

            // Create chat session
            self.chatSession = ChatSession(model)

            print("✅ SpeechCleaner: Model initialized")

        } catch {
            print("❌ SpeechCleaner: Model load failed: \(error)")
            throw SpeechCleanerError.modelLoadFailed(error)
        }
    }

    /// Clean up raw transcription using LLM
    /// - Parameter rawText: Raw transcription from Whisper
    /// - Returns: Cleaned text
    func clean(_ rawText: String) async throws -> String {
        print("🧹 SpeechCleaner: Cleaning '\(rawText)'")

        guard let session = chatSession else {
            throw SpeechCleanerError.notInitialized
        }

        do {
            // Build full prompt with system instructions + user request
            let fullPrompt = """
            \(systemPrompt)

            Clean this transcription: \(rawText)
            """

            // Generate response
            let rawResponse = try await session.respond(to: fullPrompt)

            // Qwen models may include thinking tags - extract final answer
            var cleanedText = rawResponse
            if let thinkEndRange = rawResponse.range(of: "</think>") {
                // Extract everything after the closing think tag
                cleanedText = String(rawResponse[thinkEndRange.upperBound...])
            }

            // Clean up the output
            cleanedText = cleanedText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "^[\\s\\n]+", with: "", options: .regularExpression)

            guard !cleanedText.isEmpty else {
                throw SpeechCleanerError.emptyResponse
            }

            print("✅ SpeechCleaner: '\(rawText)' → '\(cleanedText)'")
            return cleanedText

        } catch {
            print("❌ SpeechCleaner: Generation failed: \(error)")
            throw SpeechCleanerError.generationFailed(error)
        }
    }
}

/// Speech cleaner errors
enum SpeechCleanerError: Error, LocalizedError {
    case notInitialized
    case modelLoadFailed(Error)
    case generationFailed(Error)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "SpeechCleaner not initialized"
        case .modelLoadFailed(let error):
            return "Model load failed: \(error.localizedDescription)"
        case .generationFailed(let error):
            return "Text generation failed: \(error.localizedDescription)"
        case .emptyResponse:
            return "LLM returned empty response"
        }
    }
}
