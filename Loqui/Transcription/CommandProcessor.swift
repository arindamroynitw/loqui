//
//  CommandProcessor.swift
//  Loqui
//
//  Voice command detection and execution using LLM
//

import Foundation

/// Processes voice editing commands in transcribed text
@MainActor
class CommandProcessor {

    // Command processing prompt
    private let commandPrompt = """
    Extract and execute voice editing commands from this transcript.

    Supported commands:
    - "replace X with Y" / "change X to Y" / "swap X for Y": Replace word/phrase
    - "scratch that" / "undo that" / "delete that": Remove last sentence
    - "new paragraph" / "new line": Add formatting breaks
    - "all caps X" / "capitalize X": Change case

    Rules:
    - Execute commands in order, but process "undo" last-to-first
    - Remove command text from output
    - If command fails (word not found), silently skip it
    - For "replace", use context to determine which instance if multiple exist

    Transcript:
    %TRANSCRIPT%

    Return only the final edited text with commands removed and executed. No explanations.
    """

    /// Process commands in transcript using LLM
    /// - Parameters:
    ///   - transcript: Raw transcript from Whisper
    ///   - llmClient: LLM client for command processing
    /// - Returns: Transcript with commands executed and removed
    func processCommands(transcript: String, llmClient: LLMClient?) async throws -> String {
        print("🎮 CommandProcessor: Processing commands in '\(transcript)'")

        // If no LLM client, return transcript unchanged
        guard let llmClient = llmClient else {
            print("⚠️  CommandProcessor: No LLM client, returning original")
            return transcript
        }

        // Replace placeholder with actual transcript
        let prompt = commandPrompt.replacingOccurrences(of: "%TRANSCRIPT%", with: transcript)

        // Use GroqClient's complete method
        do {
            let processedText = try await llmClient.complete(prompt: prompt)
            print("✅ CommandProcessor: '\(transcript)' → '\(processedText)'")
            return processedText
        } catch {
            // If command processing fails, return original transcript
            print("⚠️  CommandProcessor: Failed (\(error)), returning original")
            return transcript
        }
    }
}
