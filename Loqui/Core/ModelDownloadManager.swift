//
//  ModelDownloadManager.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Foundation
// WhisperKit will be imported once the dependency is added
// import WhisperKit

/// Manages downloading of Whisper and LLM models
@MainActor
class ModelDownloadManager: ObservableObject {
    @Published var downloadProgress: Double = 0.0
    @Published var currentTask: String = ""
    @Published var isDownloading: Bool = false

    /// Download all required models (Whisper + LLM)
    func downloadModels() async throws {
        isDownloading = true

        // Phase 3: Download Whisper model only
        currentTask = "Downloading Whisper model (594MB)..."
        print("📥 ModelDownloadManager: \(currentTask)")

        try await downloadWhisperModel { progress in
            self.downloadProgress = progress
        }

        // TODO Phase 4: Download LLM model
        // currentTask = "Downloading LLM model (~5GB)..."
        // try await downloadLLMModel { progress in
        //     self.downloadProgress = 0.4 + (progress * 0.6)  // 60% of total
        // }

        currentTask = "Download complete!"
        downloadProgress = 1.0
        isDownloading = false

        print("✅ ModelDownloadManager: All models downloaded")
    }

    /// Download Whisper model
    private func downloadWhisperModel(progress: @escaping (Double) -> Void) async throws {
        // TODO: Uncomment once WhisperKit is added
        /*
        let config = WhisperKitConfig(
            model: "distil-large-v3",
            downloadBase: nil,
            useBackgroundDownloadSession: false
        )

        // WhisperKit.download() with progress callback
        _ = try await WhisperKit.download(config: config) { downloadProgress in
            progress(downloadProgress.fractionCompleted)
        }
        */

        // TEMPORARY: Stub for Phase 3 testing without WhisperKit
        // Simulate download with progress
        for i in 0...100 {
            try await Task.sleep(nanoseconds: 20_000_000)  // 20ms per percent
            progress(Double(i) / 100.0)
        }

        print("✅ ModelDownloadManager: (Stub) Whisper model downloaded")
    }

    /// Download LLM model (Phase 4)
    private func downloadLLMModel(progress: @escaping (Double) -> Void) async throws {
        // TODO Phase 4: Implement MLX model download
        print("📥 ModelDownloadManager: LLM download (Phase 4)")
    }
}
