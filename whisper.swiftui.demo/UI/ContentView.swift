import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject var whisperState = WhisperState()
    let audioProcessor = RealTimeAudioProcessor()
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
//                    Button("Transcribe", action: {
//                        Task {
//                            await whisperState.transcribeMySample()
//                        }
//                    })
//                    .buttonStyle(.bordered)
//                    .disabled(!whisperState.canTranscribe)
//
//                    Button(whisperState.isRecording ? "Stop recording" : "Start recording", action: {
//                        Task {
//                            await whisperState.toggleRecord()
//                        }
//                    })
//                    .buttonStyle(.bordered)
//                    .disabled(!whisperState.canTranscribe)
                    
                    Button("start realtime", action: {
                        Task {
                            // Example usage:
                            audioProcessor.canStop = true
                            do {
                                audioProcessor.setWhisperStateDelegate(state: whisperState)
                                try audioProcessor.startRealTimeProcessingAndPlayback()
                            } catch {
                                print("Error starting real-time processing and playback: \(error.localizedDescription)")
                            }
                        }
                    }).buttonStyle(.bordered)
                        .disabled(audioProcessor.canStop)
                    
                    Button("stop realtime", action: {
                        Task {
                            audioProcessor.stopRecord()
                            audioProcessor.canStop = false
                        }
                    }).buttonStyle(.bordered)
                        .disabled(!audioProcessor.canStop)
                }
                
                ScrollView {
                    Text(verbatim: whisperState.translateText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("Whisper SwiftUI Demo")
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
