//
//  ModelDownloadView.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import SwiftUI

/// First-launch model download UI
struct ModelDownloadView: View {
    @StateObject private var downloadManager = ModelDownloadManager()
    @State private var downloadComplete = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            if downloadComplete {
                // Success state
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Ready to Go!")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Loqui is ready to transcribe your speech.\nPress and hold fn to start.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Get Started") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 10)

            } else {
                // Downloading state
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Setting up Loqui")
                    .font(.title)
                    .fontWeight(.semibold)

                Text(downloadManager.currentTask)
                    .font(.body)
                    .foregroundColor(.secondary)

                ProgressView(value: downloadManager.downloadProgress, total: 1.0)
                    .frame(width: 300)

                Text("\(Int(downloadManager.downloadProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(30)
        .frame(width: 400, height: 300)
        .onAppear {
            startDownload()
        }
    }

    private func startDownload() {
        Task {
            do {
                try await downloadManager.downloadModels()
                downloadComplete = true
            } catch {
                print("❌ Model download failed: \(error)")
                LoquiLogger.shared.logError(error, context: "Model download")
                // TODO: Show error alert
            }
        }
    }
}

#Preview {
    ModelDownloadView()
}
