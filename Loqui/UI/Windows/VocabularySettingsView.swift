//
//  VocabularySettingsView.swift
//  Loqui
//
//  Settings view for custom vocabulary management
//

import SwiftUI

/// Settings view for managing custom vocabulary
struct VocabularySettingsView: View {
    @ObservedObject var manager = VocabularyManager.shared
    @State private var newTerm = ""
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importCount = 0
    @State private var importErrorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Custom Vocabulary")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add names, companies, and technical terms for accurate transcription")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Add new term section
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Term")
                    .font(.headline)

                HStack {
                    TextField("Enter name, company, or technical term", text: $newTerm)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addTerm() }

                    Button("Add") { addTerm() }
                        .keyboardShortcut(.return, modifiers: [])
                        .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Divider()

            // Import/Export section
            HStack(spacing: 12) {
                Button("Import CSV") { importCSV() }
                Button("Export CSV") { exportCSV() }
                    .disabled(manager.vocabulary.isEmpty)
            }

            Divider()

            // Vocabulary list
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Vocabulary List")
                        .font(.headline)
                    Spacer()
                    Text("\(manager.vocabulary.count) terms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if manager.vocabulary.isEmpty {
                    Text("No vocabulary terms yet. Add terms above or import from CSV.")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.vertical, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(manager.vocabulary, id: \.self) { term in
                                HStack {
                                    Text(term)
                                        .font(.body)
                                    Spacer()
                                    Button(action: { manager.removeTerm(term) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove '\(term)'")
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)

                                if term != manager.vocabulary.last {
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                    .border(Color.secondary.opacity(0.2), width: 1)
                }
            }

            Spacer()
        }
        .padding(20)
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK") { }
        } message: {
            Text("Imported \(importCount) new terms")
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK") { }
        } message: {
            Text(importErrorMessage)
        }
    }

    // MARK: - Actions

    private func addTerm() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        manager.addTerm(trimmed)
        newTerm = ""
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a CSV file with vocabulary terms"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                let count = try manager.importCSV(from: url)
                importCount = count
                showImportSuccess = true
            } catch {
                importErrorMessage = error.localizedDescription
                showImportError = true
            }
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "loqui-vocabulary.csv"
        panel.message = "Export vocabulary to CSV file"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                try manager.exportCSV(to: url)
            } catch {
                importErrorMessage = "Export failed: \(error.localizedDescription)"
                showImportError = true
            }
        }
    }
}

#Preview {
    VocabularySettingsView()
        .frame(width: 500, height: 450)
}
