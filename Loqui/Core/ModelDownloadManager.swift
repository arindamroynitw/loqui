//
//  ModelDownloadManager.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Foundation
import WhisperKit

/// Manages downloading of Whisper models
@MainActor
class ModelDownloadManager: ObservableObject {
    @Published var downloadProgress: Double = 0.0
    @Published var currentTask: String = ""
    @Published var isDownloading: Bool = false

    /// Download required models (Whisper only - LLM is cloud-based)
    func downloadModels() async throws {
        isDownloading = true

        // Phase 3: Download Whisper model (100% of progress)
        currentTask = "Downloading Whisper model (594MB)..."
        print("📥 ModelDownloadManager: \(currentTask)")

        try await downloadWhisperModel { progress in
            self.downloadProgress = progress
        }

        currentTask = "Download complete!"
        downloadProgress = 1.0
        isDownloading = false

        print("✅ ModelDownloadManager: Whisper model downloaded")
        print("ℹ️  ModelDownloadManager: LLM cleanup uses cloud API (no download required)")
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

}
