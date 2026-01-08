//
//  LoquiLogger.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import Foundation
import OSLog

/// Centralized logging for Loqui
class LoquiLogger {
    static let shared = LoquiLogger()

    private let logger = Logger(subsystem: "com.loqui.app", category: "main")
    private let logDirectory: URL
    private let logFile: URL

    private init() {
        print("📍 INIT CHECKPOINT: LoquiLogger.init() - BEFORE directory creation")

        // Set up log directory: ~/Library/Application Support/Loqui/logs/
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        logDirectory = appSupport.appendingPathComponent("Loqui/logs", isDirectory: true)
        logFile = logDirectory.appendingPathComponent("loqui.log")

        print("📍 INIT CHECKPOINT: LoquiLogger - About to create directory at: \(logDirectory.path)")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)

        print("📍 INIT CHECKPOINT: LoquiLogger - AFTER directory creation")
        print("📁 LoquiLogger: Log file at \(logFile.path)")
    }

    /// Log an error with context
    func logError(_ error: Error, context: String) {
        let message = "[\(context)] \(error.localizedDescription)"
        logger.error("\(message)")
        appendToLogFile("[ERROR] \(message)")
    }

    /// Log informational message
    func logInfo(_ message: String) {
        logger.info("\(message)")
        appendToLogFile("[INFO] \(message)")
    }

    /// Log warning
    func logWarning(_ message: String) {
        logger.warning("\(message)")
        appendToLogFile("[WARNING] \(message)")
    }

    /// Append message to log file
    private func appendToLogFile(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"

        guard let data = logEntry.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFile.path) {
            // Append to existing file
            if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        } else {
            // Create new file
            try? data.write(to: logFile)
        }
    }

    /// Clear old log files (keep last 7 days, max 10MB)
    func rotateLogs() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: logFile.path),
              let fileSize = attributes[.size] as? UInt64 else { return }

        // If file is larger than 10MB, rotate it
        if fileSize > 10_000_000 {
            let rotatedFile = logFile.deletingPathExtension().appendingPathExtension("old.log")
            try? FileManager.default.removeItem(at: rotatedFile) // Remove old backup
            try? FileManager.default.moveItem(at: logFile, to: rotatedFile) // Rotate current
        }
    }
}
