//
//  WhisperAudioCapture.swift
//  Loqui
//
//  Created by Arindam Roy on 31/12/25.
//

import AVFoundation
import Foundation

/// Captures audio from microphone and converts to Whisper-compatible format
/// Whisper requires: 16kHz, 16-bit mono PCM
class WhisperAudioCapture {
    private let audioEngine = AVAudioEngine()
    private var converter: AVAudioConverter?

    /// Whisper's required audio format: 16kHz, 16-bit mono PCM
    private let whisperFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    /// Callback invoked for each audio chunk (in Whisper format)
    var onAudioChunk: ((Data) -> Void)?

    /// Start capturing audio from the microphone
    func startCapture() throws {
        print("📍 INIT CHECKPOINT: WhisperAudioCapture.startCapture() - BEFORE accessing inputNode")

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        print("📍 INIT CHECKPOINT: WhisperAudioCapture - AFTER accessing inputNode")
        print("🎤 Audio Input Format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")
        print("🎯 Whisper Target Format: 16000Hz, 1 channel, Int16")

        // Create format converter
        guard let converter = AVAudioConverter(from: inputFormat, to: whisperFormat) else {
            throw AudioError.converterCreationFailed
        }
        self.converter = converter

        // Install audio tap on input node
        // Buffer size 4096 samples = ~23-93ms at 44.1kHz
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            self?.processBuffer(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        print("✅ Audio capture started")
    }

    /// Stop capturing audio
    func stopCapture() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        print("🛑 Audio capture stopped")
    }

    /// Process audio buffer: convert format and send to callback
    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converter = converter else { return }

        // Calculate output buffer size based on sample rate ratio
        let ratio = whisperFormat.sampleRate / buffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: whisperFormat,
            frameCapacity: outputCapacity
        ) else {
            print("❌ Failed to create output buffer")
            return
        }

        // Convert audio format
        var inputConsumed = false
        let status = converter.convert(to: outputBuffer, error: nil) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        // Check conversion status
        if status == .error {
            print("❌ Audio conversion error")
            return
        }

        // Extract Int16 samples and send to callback
        if let channelData = outputBuffer.int16ChannelData {
            let data = Data(bytes: channelData[0], count: Int(outputBuffer.frameLength) * 2)
            onAudioChunk?(data)
        }
    }

    deinit {
        stopCapture()
    }
}
