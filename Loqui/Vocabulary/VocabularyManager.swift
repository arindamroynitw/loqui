//
//  VocabularyManager.swift
//  Loqui
//
//  Custom vocabulary manager for proper noun correction
//

import Foundation
import Combine

/// Manages custom vocabulary list for LLM-based correction
/// Singleton pattern with JSON persistence
@MainActor
class VocabularyManager: ObservableObject {
    static let shared = VocabularyManager()

    @Published private(set) var vocabulary: [String] = []

    private let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let loquiDir = appSupport.appendingPathComponent("Loqui", isDirectory: true)
        try? FileManager.default.createDirectory(at: loquiDir, withIntermediateDirectories: true)
        return loquiDir.appendingPathComponent("vocabulary.json")
    }()

    private init() {
        loadVocabulary()
    }

    // MARK: - Public API

    /// Add a term to the vocabulary (with deduplication)
    func addTerm(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !vocabulary.contains(trimmed) else { return }

        vocabulary.append(trimmed)
        vocabulary.sort()
        saveVocabulary()
        print("📚 VocabularyManager: Added '\(trimmed)' (total: \(vocabulary.count))")
    }

    /// Remove a term from the vocabulary
    func removeTerm(_ term: String) {
        vocabulary.removeAll { $0 == term }
        saveVocabulary()
        print("📚 VocabularyManager: Removed '\(term)' (total: \(vocabulary.count))")
    }

    /// Import vocabulary from CSV file
    /// - Parameter url: CSV file URL
    /// - Returns: Number of terms imported
    func importCSV(from url: URL) throws -> Int {
        print("📚 VocabularyManager: Importing from \(url.lastPathComponent)")

        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var imported = 0
        for line in lines.dropFirst() { // Skip header row
            let term = line.trimmingCharacters(in: .whitespaces)
            guard !term.isEmpty else { continue }

            if !vocabulary.contains(term) {
                vocabulary.append(term)
                imported += 1
            }
        }

        vocabulary.sort()
        saveVocabulary()

        print("✅ VocabularyManager: Imported \(imported) new terms (total: \(vocabulary.count))")
        return imported
    }

    /// Export vocabulary to CSV file
    /// - Parameter url: Destination CSV file URL
    func exportCSV(to url: URL) throws {
        print("📚 VocabularyManager: Exporting to \(url.lastPathComponent)")

        var csv = "term\n"
        csv += vocabulary.joined(separator: "\n")

        try csv.write(to: url, atomically: true, encoding: .utf8)

        print("✅ VocabularyManager: Exported \(vocabulary.count) terms")
    }

    // MARK: - Private Helpers

    private func loadVocabulary() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let terms = try? JSONDecoder().decode([String].self, from: data) else {
            print("📚 VocabularyManager: No existing vocabulary found, starting fresh")
            vocabulary = []
            return
        }

        vocabulary = terms.sorted()
        print("📚 VocabularyManager: Loaded \(vocabulary.count) terms from \(fileURL.path)")
    }

    private func saveVocabulary() {
        guard let data = try? JSONEncoder().encode(vocabulary) else {
            print("❌ VocabularyManager: Failed to encode vocabulary")
            return
        }

        do {
            try data.write(to: fileURL, options: .atomic)
            print("💾 VocabularyManager: Saved \(vocabulary.count) terms to \(fileURL.path)")
        } catch {
            print("❌ VocabularyManager: Failed to save vocabulary: \(error)")
        }
    }
}
