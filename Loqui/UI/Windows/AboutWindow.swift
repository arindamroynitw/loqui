//
//  AboutWindow.swift
//  Loqui
//
//  Created by Arindam Roy on 02/01/26.
//

import SwiftUI

struct AboutWindow: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background gradient (matching app icon)
            LinearGradient(
                colors: [Color(hex: "0080ff"), Color(hex: "00a3d9")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Content
            VStack(spacing: 16) {
                // Logo
                Image("MenuBarIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white)

                // App name
                Text("Loqui")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)

                // Tagline
                Text("Fast Speech-to-Text for macOS")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.9))

                // Version (dynamic from Bundle)
                Text("Version \(appVersion) (Build \(buildNumber))")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))

                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.horizontal, 40)

                // Description
                VStack(spacing: 12) {
                    Text("Loqui provides instant, on-device speech-to-text transcription with AI-powered cleanup. Press and hold fn to record, release to transcribe.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 40)

                    Text("🔒 Private. No data stored or sent anywhere.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                }

                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.horizontal, 40)

                // License
                VStack(spacing: 8) {
                    Text("Licensed under Proprietary License")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))

                    Button("View License") {
                        if let url = URL(string: "https://github.com/arindamroynitw/loqui/blob/main/LICENSE") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                // Footer
                VStack(spacing: 8) {
                    Text("Made by Arindam Roy")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))

                    // Creator's social links
                    HStack(spacing: 20) {
                        Link(destination: URL(string: "https://x.com/crosschainyoda")!) {
                            Label("Twitter", systemImage: "bird")
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Link(destination: URL(string: "https://www.linkedin.com/in/arindamroynitw/")!) {
                            Label("LinkedIn", systemImage: "link")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .font(.system(size: 12))
                }
                .padding(.bottom, 32)
            }
            .padding(.top, 32)
        }
        .frame(width: 400, height: 480)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Preview

#Preview {
    AboutWindow()
}
