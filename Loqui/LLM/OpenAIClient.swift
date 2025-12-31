//
//  OpenAIClient.swift
//  Loqui
//
//  OpenAI API client for LLM-based transcript cleanup (fallback provider)
//

import Foundation

/// OpenAI API client for reliable cloud-based LLM inference
@MainActor
class OpenAIClient {
    // MARK: - Properties
    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    private let timeout: TimeInterval = 5.0
    private let model = "gpt-4o-mini"

    // Fixed cleanup prompt (same as Groq for consistency)
    private let systemPrompt = """
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
    """

    // MARK: - Initialization
    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Public API
    /// Clean transcript using OpenAI API
    /// - Parameter rawText: Raw transcription from Whisper
    /// - Returns: Cleaned text
    /// - Throws: LLMError on failure
    func cleanTranscript(_ rawText: String) async throws -> String {
        print("🔷 OpenAIClient: Cleaning '\(rawText)'")

        // Build request
        let request = try makeRequest(rawText)

        // Execute with timeout
        do {
            let (data, response) = try await executeWithTimeout(request)

            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw mapHTTPError(statusCode: httpResponse.statusCode, data: data)
            }

            // Decode response
            let openaiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)

            guard let cleanedText = openaiResponse.choices.first?.message.content,
                  !cleanedText.isEmpty else {
                throw LLMError.emptyResponse
            }

            print("✅ OpenAIClient: '\(rawText)' → '\(cleanedText)'")
            return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch let error as LLMError {
            print("❌ OpenAIClient: \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ OpenAIClient: Unexpected error: \(error)")
            throw LLMError.networkError(error)
        }
    }

    // MARK: - Private Helpers

    private func makeRequest(_ rawText: String) throws -> URLRequest {
        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        // Build request body (OpenAI format)
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Clean this transcription: \(rawText)"]
            ],
            "temperature": 0.3,
            "max_tokens": 100
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func executeWithTimeout(_ request: URLRequest) async throws -> (Data, URLResponse) {
        // Use URLSession with built-in timeout from request.timeoutInterval
        return try await URLSession.shared.data(for: request)
    }

    private func mapHTTPError(statusCode: Int, data: Data) -> LLMError {
        // Try to decode error message from response
        if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
            return LLMError.apiError(statusCode: statusCode, message: errorResponse.error.message)
        }

        switch statusCode {
        case 401:
            return LLMError.invalidAPIKey
        case 429:
            return LLMError.rateLimited
        case 500...599:
            return LLMError.serverError(statusCode)
        default:
            return LLMError.apiError(statusCode: statusCode, message: "HTTP \(statusCode)")
        }
    }
}

// MARK: - Response Models

private struct OpenAIResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

private struct OpenAIErrorResponse: Codable {
    let error: ErrorDetail

    struct ErrorDetail: Codable {
        let message: String
    }
}
