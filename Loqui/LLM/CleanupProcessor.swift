//
//  CleanupProcessor.swift
//  Loqui
//
//  Enhanced LLM-based transcript cleanup with vocabulary correction
//

import Foundation

// MARK: - Cleanup Processor
// Note: PauseHint and PauseType are defined in TranscriptionEngine.swift

/// Enhanced cleanup processor with vocabulary correction and pause-based formatting
@MainActor
class CleanupProcessor {

    /// Clean transcript with enhanced features
    /// - Parameters:
    ///   - text: Transcript to clean (after command processing)
    ///   - vocabulary: Custom vocabulary terms
    ///   - llmClient: LLM client for cleanup
    /// - Returns: Cleaned transcript
    func clean(
        text: String,
        vocabulary: [String],
        llmClient: LLMClient?
    ) async throws -> String {
        print("🧹 CleanupProcessor: Cleaning '\(text)' (vocab: \(vocabulary.count))")

        // Detect list patterns for logging
        let hasFirstSecondThird = text.contains("First") || text.contains("Second") || text.contains("Third")
        let hasOneTwoThree = text.contains(" One ") || text.contains(" Two ") || text.contains(" Three ")
        if hasFirstSecondThird || hasOneTwoThree {
            print("📋 CleanupProcessor: List markers detected - First/Second/Third: \(hasFirstSecondThird), One/Two/Three: \(hasOneTwoThree)")
        }

        // If no LLM client, return text unchanged
        guard let llmClient = llmClient else {
            print("⚠️  CleanupProcessor: No LLM client, returning original")
            return text
        }

        // Build cleanup prompt
        let prompt = buildCleanupPrompt(text: text, vocabulary: vocabulary)
        print("📝 CleanupProcessor: Prompt length: \(prompt.count) chars, has vocab: \(!vocabulary.isEmpty)")

        // Use GroqClient's complete method
        do {
            let cleanedText = try await llmClient.complete(prompt: prompt)
            print("✅ CleanupProcessor: '\(text)' → '\(cleanedText)'")
            return cleanedText
        } catch {
            // If cleanup fails, return original text
            print("⚠️  CleanupProcessor: Failed (\(error)), returning original")
            return text
        }
    }

    // MARK: - Private Helpers

    private func buildCleanupPrompt(text: String, vocabulary: [String]) -> String {
        var prompt = """
        You are a transcript cleaner. Your job is to clean speech-to-text output while preserving the speaker's intent.

        RULES:
        1. Remove filler words (um, uh, like, you know, I mean, basically, actually)
           - Exception: Preserve semantic use (e.g., "I like pizza" → keep "like")

        2. Remove false starts and self-corrections
           - Keep only the final corrected version
           - Example: "let's meet Monday, no wait, Tuesday" → "let's meet Tuesday"

        3. Format list structures when detected:
           - When you see 2+ consecutive list markers ("First... Second..." OR "One... Two..."):
             * Replace "First" with "1.", "Second" with "2.", "Third" with "3.", etc.
             * Replace "One" with "1.", "Two" with "2.", "Three" with "3.", etc.
             * Put each list item on a new line
           - If only ONE list marker appears in isolation, keep it as-is

        4. Add paragraph breaks where natural topic shifts occur
           - Use your semantic understanding to identify logical breaks
           - Insert double newlines (\\n\\n) between distinct topics or sections

        5. Fix grammar and punctuation

        """

        // Add vocabulary section if available
        if !vocabulary.isEmpty {
            let vocabList = vocabulary.prefix(50).joined(separator: ", ")  // Limit to 50 terms
            let remaining = vocabulary.count > 50 ? " (and \(vocabulary.count - 50) more)" : ""

            print("📚 CleanupProcessor: Sending vocabulary to LLM: [\(vocabList)]\(remaining)")

            prompt += """
            6. Correct ONLY misspelled/misheard proper nouns using this vocabulary:
               \(vocabList)\(remaining)
               - ONLY correct if the word sounds similar but is misspelled
               - Examples: "neeraj" → "Neeraj", "sukpal" → "Sukhpal"
               - Do NOT replace correctly spelled technical terms or acronyms

            """
        }

        prompt += """

        TRANSCRIPT TO CLEAN:
        \(text)

        Return ONLY the cleaned version. Do not add content not in the original.
        """

        return prompt
    }
}
