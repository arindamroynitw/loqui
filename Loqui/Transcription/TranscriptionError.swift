//
//  TranscriptionError.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Foundation

/// Errors that can occur during transcription
enum TranscriptionError: LocalizedError {
    case notInitialized
    case emptyResult
    case timeout
    case failed(Error)
    case modelNotFound
    case invalidAudioFormat

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Transcription engine not initialized"
        case .emptyResult:
            return "Transcription returned empty result"
        case .timeout:
            return "Transcription timeout (>30 seconds)"
        case .failed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .modelNotFound:
            return "Whisper model not found - please download first"
        case .invalidAudioFormat:
            return "Invalid audio format for transcription"
        }
    }
}
