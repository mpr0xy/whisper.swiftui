import AVFoundation

class RealTimeAudioProcessor {
    let audioEngine = AVAudioEngine()
    let audioSession = AVAudioSession.sharedInstance()
    var audioBuffer: AVAudioPCMBuffer?
    var lastBuffer: AVAudioPCMBuffer?
    var audioPlayer: AVAudioPlayer?
    var formatConverter: AVAudioConverter!
    var whisperStateDelegate:WhisperState!
    var dataFloats = [Float]()
    var canStop = false
    
    func setWhisperStateDelegate (state: WhisperState) {
        whisperStateDelegate = state
    }
    
    // Assume you have an AVAudioPCMBuffer named audioBuffer
    
    func startRealTimeProcessingAndPlayback() throws {
        try audioSession.setCategory(.playAndRecord, mode: .default)
        
        // 请求录音权限
        audioSession.requestRecordPermission { granted in
            if granted {
                // 用户已授予录音权限，继续启动实时处理和播放
                do {
                    try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    
                    let inputNode = self.audioEngine.inputNode
                    
                    let format = inputNode.inputFormat(forBus: 0)
                    
                    // 需要把音频转换为16000Rate, 转换commonFormat会引起错误
                    let outputFormat = AVAudioFormat(
                        commonFormat: .pcmFormatFloat32,
                        sampleRate: 16000,
                        channels: 1,
                        interleaved: true
                    )!
                    self.formatConverter = AVAudioConverter(from: format, to: outputFormat)!
                    
                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
                        DispatchQueue.main.async {
                            do {
                                let duration = Double(buffer.frameCapacity) / buffer.format.sampleRate
                                let outputBufferCapacity = AVAudioFrameCount(outputFormat.sampleRate * duration)
                                let outputBuffer = AVAudioPCMBuffer(
                                    pcmFormat: outputFormat,
                                    frameCapacity: outputBufferCapacity
                                )!
                                var error: NSError? = nil
                                if self.formatConverter != nil {
                                    let status = self.formatConverter.convert(
                                        to: outputBuffer,
                                        error: &error,
                                        withInputFrom: { inNumPackets, outStatus in
                                            outStatus.pointee = AVAudioConverterInputStatus.haveData
                                            return buffer
                                        }
                                    )
                                    switch status {
                                        case .error:
                                            if let conversionError = error {
                                              print("Error converting audio file: \(conversionError)")
                                            }
                                            return
                                        default: break
                                    }
                                    self.formatConverter?.reset()
                                }
                                let oneFloat = try self.decodePCMBuffer(outputBuffer)
                                self.dataFloats += oneFloat
                                let tempDateFloats = self.dataFloats
                                Task {
                                    await self.whisperStateDelegate.transcribeData(tempDateFloats)
                                }
                            } catch {
                                print("Write error: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    // 启动音频引擎
                    try self.audioEngine.start()
                    
                    print("Real-time audio processing and playback started.")
                } catch {
                    print("Error starting real-time processing and playback: \(error.localizedDescription)")
                }
            } else {
                // 用户未授予录音权限
                print("User denied record permission.")
            }
        }
    }
    
    func decodePCMBuffer(_ buffer: AVAudioPCMBuffer) throws -> [Float] {
        guard let floatChannelData = buffer.floatChannelData else {
            throw NSError(domain: "Invalid PCM Buffer", code: 0, userInfo: nil)
        }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        var floats = [Float]()
        
        for frame in 0..<frameLength {
            for channel in 0..<channelCount {
                let floatData = floatChannelData[channel]
                let index = frame * channelCount + channel
                let floatSample = floatData[index]
                floats.append(max(-1.0, min(floatSample, 1.0)))
            }
        }
        
        return floats
    }
    
    func stopRecord() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}
