//
//  LLMClient.swift
//  Loqui
//
//  Protocol for LLM clients
//

import Foundation

/// Protocol for LLM clients that support generic completion
protocol LLMClient {
    /// Generic LLM completion with custom prompt
    /// - Parameter prompt: The prompt to send to the LLM
    /// - Returns: LLM response text
    /// - Throws: LLMError on failure
    func complete(prompt: String) async throws -> String
}

// MARK: - Conformance

extension GroqClient: LLMClient {}
extension OpenAIClient: LLMClient {}
