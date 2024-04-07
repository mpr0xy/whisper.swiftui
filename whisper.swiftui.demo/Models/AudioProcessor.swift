//
//  AudioProcessor.swift
//  whisper.swiftui
//
//  Created by i on 2024/3/28.
//

import AVFoundation

class AudioProcessor {
    let audioEngine = AVAudioEngine()
    var audioBuffer = AVAudioPCMBuffer()

    func startRecording() {
        requestRecordPermission { granted in
            if granted {
                Task {
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setCategory(.record, mode: .default, options: [])
                        try audioSession.setActive(true)
                        
                        let format = self.audioEngine.inputNode.inputFormat(forBus: 0)
                        let bufferSize = AVAudioFrameCount(8 * format.sampleRate) // 8 seconds buffer size
                        self.audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize)!
                        
                        self.audioEngine.connect(self.audioEngine.inputNode, to: self.audioEngine.mainMixerNode, format: format)
                        
                        self.audioEngine.inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { (buffer, time) in
                            self.processAudioBuffer(buffer)
                        }
                        
                        try self.audioEngine.start()
                    } catch {
                        print("Error starting audio engine: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func convertPCMBufferToFloatArray(buffer: AVAudioPCMBuffer) -> [Float] {
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        let floatChannelData = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[0], count: frameLength))

        var floats = [Float]()

        for frame in 0 ..< frameLength {
            for channel in 0 ..< channelCount {
                let index = frame * channelCount + channel
                floats.append(floatChannelData[index])
            }
        }

        return floats
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Process the audio buffer here
        // This function will be called whenever a new buffer is available
        // You can access the audio data using buffer.floatChannelData
        
        // Example: print the number of frames in the buffer
        print("Buffer frames: \(buffer.frameLength)")
        let data = convertPCMBufferToFloatArray(buffer: buffer)
        
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    private func requestRecordPermission(response: @escaping (Bool) -> Void) {
#if os(macOS)
        response(true)
#else
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            response(granted)
        }
#endif
    }
}

// Example usage:


// To stop recording:
// audioProcessor.stopRecording()


