import Foundation
import SwiftUI
import AVFoundation

@MainActor
class WhisperState: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isModelLoaded = false
    @Published var messageLog = ""
    @Published var translateText = ""
    @Published var canTranscribe = false
    @Published var isRecording = false
    
    private var whisperContext: WhisperContext?
    private let recorder = Recorder()
    private var recordedFile: URL? = nil
    private var audioPlayer: AVAudioPlayer?
    private let audioEngine = AVAudioEngine()
    private var audioBuffer = AVAudioPCMBuffer()
    private var accumulatedBuffer: AVAudioPCMBuffer?
    private var accumulatedData = [Float]()
    private var isRuning: Bool = false;
    var audioFile: AVAudioFile!
    var recordingURL: URL!
    private let chunkDuration: TimeInterval = 5 // 8 seconds
    
    private var modelUrl: URL? {
        Bundle.main.url(forResource: "ggml-tiny.en", withExtension: "bin", subdirectory: "models")
    }
    
    private var sampleUrl: URL? {
        Bundle.main.url(forResource: "jfk", withExtension: "wav", subdirectory: "samples")
    }
    
    private var mySampleUrl: URL!
    
    private enum LoadError: Error {
        case couldNotLocateModel
    }
    
    override init() {
        super.init()
        do {
            try loadModel()
            canTranscribe = true
        } catch {
            print(error.localizedDescription)
            messageLog += "\(error.localizedDescription)\n"
        }
    }
    
    private func loadModel() throws {
        messageLog += "Loading model...\n"
        if let modelUrl {
            whisperContext = try WhisperContext.createContext(path: modelUrl.path())
            messageLog += "Loaded model \(modelUrl.lastPathComponent)\n"
        } else {
            messageLog += "Could not locate model\n"
        }
    }
    
    func transcribeSample() async {
        if let sampleUrl {
            await transcribeAudio(sampleUrl)
        } else {
            messageLog += "Could not locate sample\n"
        }
    }
    
    func transcribeMySample() async {
        do {
            mySampleUrl = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
               .appending(path: "test2.wav")
            if let mySampleUrl {
                await transcribeAudio(mySampleUrl)
            } else {
                messageLog += "Could not locate mySample\n"
            }
        } catch {
            print("error \(error.localizedDescription)")
        }
    }
    
    func transcribeAudio(_ url: URL) async {
        if (!canTranscribe) {
            return
        }
        guard let whisperContext else {
            return
        }
        
        do {
            canTranscribe = false
            messageLog += "Reading wave samples...\n"
            let data = try readAudioSamples(url)
            messageLog += "Transcribing data...\n"
            await whisperContext.fullTranscribe(samples: data)
            let text = await whisperContext.getTranscription()
            messageLog += "Done: \(text)\n"
            translateText += "\(text) "
        } catch {
            print(error.localizedDescription)
            messageLog += "\(error.localizedDescription)\n"
        }
        
        canTranscribe = true
    }
    
    func transcribeData(_ data: [Float]) async {
        if (!canTranscribe) {
            return
        }
        guard let whisperContext else {
            return
        }
        
        do {
            canTranscribe = false
//            messageLog += "Reading wave samples...\n"
//            let data = try readAudioSamples(url)
//            messageLog += "Transcribing data...\n"
            await whisperContext.fullTranscribe(samples: data)
            let text = await whisperContext.getTranscription()
            messageLog += "Done: \(text)\n"
            translateText = "\(text) "
        } catch {
            print(error.localizedDescription)
            messageLog += "\(error.localizedDescription)\n"
        }
        
        canTranscribe = true
    }
    
    func startRealtime() {
        requestRecordPermission { granted in
            if granted {
                Task {
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setCategory(.record, mode: .default, options: [])
                        try audioSession.setActive(true)
                        
                        let format = self.audioEngine.inputNode.inputFormat(forBus: 0)
                        
                        self.recordingURL = URL(fileURLWithPath: NSTemporaryDirectory() + "recordedAudio.wav")
                        self.audioFile = try AVAudioFile(forWriting: self.recordingURL, settings: format.settings)
                        
                        let bufferSize = AVAudioFrameCount(5 * format.sampleRate) // 8 seconds buffer size
                        self.audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize)!
                        
                        self.audioEngine.connect(self.audioEngine.inputNode, to: self.audioEngine.mainMixerNode, format: format)
                        
                        self.audioEngine.inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { (buffer, time) in
                            self.handleAudioBuffer(buffer, time: time)
                            do {
                                try self.audioFile.write(from: buffer)
                            } catch {
                                print("Error writing audio data to file: \(error.localizedDescription)")
                            }
                        }
                        
                        try self.audioEngine.start()
                    } catch {
                        print("Error starting audio engine: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        accumulatedData += decodePCMBuffer(buffer: buffer)
        print("accumulatedData count: \(accumulatedData.count)")
        if (accumulatedData.count >= 134400) {
            if (isRuning) {
                return
            }
            processAudioBuffer(accumulatedData)
            accumulatedData.removeAll()
        }
    }
    
    func stopRealtime() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    func decodePCMBuffer(buffer: AVAudioPCMBuffer) -> [Float] {
        // 获取AVAudioPCMBuffer中的浮点数组
        guard let floatChannelData = buffer.floatChannelData else {
            return []
        }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        var floatArray = [Float]()
        
        // 将所有通道的数据合并到单个数组中
        for channel in 0..<channelCount {
            let channelData = floatChannelData[channel]
            for i in 0..<frameLength {
                floatArray.append(max(-1.0, min(channelData[i] / 32767.0, 1.0)))
            }
        }
        
        return floatArray
    }
    
    func processAudioBuffer(_ data: [Float]) {
        // Process the audio buffer here
        // This function will be called whenever a new buffer is available
        // You can access the audio data using buffer.floatChannelData
        guard let whisperContext else {
            return
        }
        // Example: print the number of frames in the buffer
//        print("Buffer frames: \(buffer.frameLength)")
//        let data = convertPCMBufferToFloatArray(buffer: buffer)
        Task {
//            messageLog += "Transcribing data...\n"
//            isRuning = true
//            await whisperContext.fullTranscribe(samples: data)
//            let text = await whisperContext.getTranscription()
//            messageLog += "Done: \(text)\n"
//            isRuning = false
            isRuning = true
            await transcribeAudio(audioFile.url)
            isRuning = false
        }
    }
    
    
    private func readAudioSamples(_ url: URL) throws -> [Float] {
        stopPlayback()
//        try startPlayback(url)
        return try decodeWaveFile2(url)
    }
    
    func toggleRecord() async {
        if isRecording {
            await recorder.stopRecording()
            isRecording = false
            if let recordedFile {
                await transcribeAudio(recordedFile)
            }
        } else {
            requestRecordPermission { granted in
                if granted {
                    Task {
                        do {
                            self.stopPlayback()
                            let file = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                                .appending(path: "output.wav")
                            try await self.recorder.startRecording(toOutputFile: file, delegate: self)
                            self.isRecording = true
                            self.recordedFile = file
                        } catch {
                            print(error.localizedDescription)
                            self.messageLog += "\(error.localizedDescription)\n"
                            self.isRecording = false
                        }
                    }
                }
            }
        }
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
    
    private func startPlayback(_ url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    // MARK: AVAudioRecorderDelegate
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error {
            Task {
                await handleRecError(error)
            }
        }
    }
    
    private func handleRecError(_ error: Error) {
        print(error.localizedDescription)
        messageLog += "\(error.localizedDescription)\n"
        isRecording = false
    }
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task {
            await onDidFinishRecording()
        }
    }
    
    private func onDidFinishRecording() {
        isRecording = false
    }
}
