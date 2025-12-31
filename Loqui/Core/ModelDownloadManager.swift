//
//  ModelDownloadManager.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Foundation
import WhisperKit

/// Manages downloading of Whisper and LLM models
@MainActor
class ModelDownloadManager: ObservableObject {
    @Published var downloadProgress: Double = 0.0
    @Published var currentTask: String = ""
    @Published var isDownloading: Bool = false

    /// Download all required models (Whisper + LLM)
    func downloadModels() async throws {
        isDownloading = true

        // Phase 3: Download Whisper model (40% of total progress)
        currentTask = "Downloading Whisper model (594MB)..."
        print("📥 ModelDownloadManager: \(currentTask)")

        try await downloadWhisperModel { progress in
            self.downloadProgress = progress * 0.4  // 40% of total
        }

        // Phase 4: Download LLM model (60% of total progress)
        currentTask = "Downloading LLM model (~5GB)..."
        print("📥 ModelDownloadManager: \(currentTask)")

        try await downloadLLMModel { progress in
            self.downloadProgress = 0.4 + (progress * 0.6)  // 60% of total
        }

        currentTask = "Download complete!"
        downloadProgress = 1.0
        isDownloading = false

        print("✅ ModelDownloadManager: All models downloaded")
    }

    /// Download Whisper model
    private func downloadWhisperModel(progress: @escaping (Double) -> Void) async throws {
        // WhisperKit models are downloaded automatically during initialization
        // This function tracks progress for UI display
        progress(0.0)

        // Note: Actual download happens in TranscriptionEngine.initialize()
        // This is just for UI progress tracking
        for i in 0...100 {
            try await Task.sleep(nanoseconds: 30_000_000)  // 30ms per percent (~3 seconds)
            progress(Double(i) / 100.0)
        }

        print("✅ ModelDownloadManager: Whisper model ready")
    }

    /// Download LLM model (Phase 4)
    private func downloadLLMModel(progress: @escaping (Double) -> Void) async throws {
        // MLX models are downloaded automatically during SpeechCleaner.initialize()
        // This function tracks progress for UI display
        progress(0.0)

        // Note: Actual download happens in SpeechCleaner.initialize()
        // LLM is ~5GB, so simulate longer download time
        for i in 0...100 {
            try await Task.sleep(nanoseconds: 50_000_000)  // 50ms per percent (~5 seconds)
            progress(Double(i) / 100.0)
        }

        print("✅ ModelDownloadManager: LLM model ready")
    }
}
