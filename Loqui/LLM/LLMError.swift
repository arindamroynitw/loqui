//
//  LLMError.swift
//  Loqui
//
//  Error types for LLM API operations
//

import Foundation

/// Errors that can occur during LLM API calls
enum LLMError: Error, LocalizedError {
    case invalidConfiguration
    case invalidAPIKey
    case networkError(Error)
    case timeout
    case rateLimited
    case serverError(Int)
    case apiError(statusCode: Int, message: String)
    case emptyResponse
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid LLM configuration"
        case .invalidAPIKey:
            return "Invalid API key (HTTP 401)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timeout (>5s)"
        case .rateLimited:
            return "Rate limited by API provider (HTTP 429)"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .apiError(let code, let message):
            return "API error (HTTP \(code)): \(message)"
        case .emptyResponse:
            return "LLM returned empty response"
        case .invalidResponse:
            return "Invalid response from LLM API"
        }
    }

    /// Whether this error should trigger fallback to raw text
    var shouldFallback: Bool {
        // All errors should fallback - we always want to insert text
        return true
    }

    /// Whether this error should be shown to the user via error overlay
    var shouldShowOverlay: Bool {
        // Show overlay for all errors except network errors (which are expected on poor connectivity)
        switch self {
        case .networkError:
            return false  // Too noisy for intermittent connectivity
        default:
            return true
        }
    }
}
