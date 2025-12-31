//
//  SettingsView.swift
//  Loqui
//
//  Settings window for API configuration
//

import SwiftUI

/// Settings view with tabs for different configuration sections
struct SettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            LLMSettingsView()
                .tabItem {
                    Label("LLM API", systemImage: "brain")
                }
                .tag(1)
        }
        .frame(width: 500, height: 450)
    }
}

/// General settings tab (placeholder for future settings)
struct GeneralSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Divider()

            Text("No general settings available yet.")
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(20)
    }
}

/// LLM API settings tab
struct LLMSettingsView: View {
    @AppStorage("groqAPIKey") private var groqAPIKey: String = ""
    @AppStorage("openaiAPIKey") private var openaiAPIKey: String = ""
    @State private var tempGroqKey: String = ""
    @State private var tempOpenAIKey: String = ""
    @State private var hasChanges: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LLM API Configuration")
                .font(.title2)
                .fontWeight(.semibold)

            Divider()

            // Groq API Key Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Primary Provider: Groq")
                    .font(.headline)

                Text("Fast, free inference using Llama 3.3 70B (~300ms)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("API Key", text: $tempGroqKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: tempGroqKey) { _, _ in
                        hasChanges = true
                    }

                Link("Get Groq API Key →", destination: URL(string: "https://console.groq.com")!)
                    .font(.caption)
            }

            Divider()

            // OpenAI API Key Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Fallback Provider: OpenAI")
                    .font(.headline)

                Text("Reliable fallback using GPT-4o-mini (~500ms)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("API Key", text: $tempOpenAIKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: tempOpenAIKey) { _, _ in
                        hasChanges = true
                    }

                Link("Get OpenAI API Key →", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.caption)
            }

            Divider()

            // Restart warning
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                Text("Changes require app restart to take effect")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action buttons
            HStack {
                Spacer()

                Button("Cancel") {
                    // Reset to saved values
                    tempGroqKey = groqAPIKey
                    tempOpenAIKey = openaiAPIKey
                    hasChanges = false
                    closeWindow()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    groqAPIKey = tempGroqKey
                    openaiAPIKey = tempOpenAIKey
                    hasChanges = false
                    closeWindow()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!hasChanges)
            }
        }
        .padding(20)
        .onAppear {
            // Load saved values on appear
            tempGroqKey = groqAPIKey
            tempOpenAIKey = openaiAPIKey
        }
    }

    private func closeWindow() {
        // Close the settings window
        NSApplication.shared.keyWindow?.close()
    }
}

#Preview {
    SettingsView()
}
