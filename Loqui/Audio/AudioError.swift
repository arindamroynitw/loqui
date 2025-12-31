//
//  AudioError.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Foundation

/// Errors that can occur during audio capture and processing
enum AudioError: LocalizedError {
    case converterCreationFailed
    case captureFailed(Error)
    case vadFailed(Error)
    case noAudioInput
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .converterCreationFailed:
            return "Failed to create audio format converter"
        case .captureFailed(let error):
            return "Audio capture failed: \(error.localizedDescription)"
        case .vadFailed(let error):
            return "Voice activity detection failed: \(error.localizedDescription)"
        case .noAudioInput:
            return "No audio input device available"
        case .permissionDenied:
            return "Microphone permission denied"
        }
    }
}
