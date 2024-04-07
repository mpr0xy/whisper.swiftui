A sample SwiftUI app using [whisper.cpp](https://github.com/ggerganov/whisper.cpp/) to do real-time voice-to-text transcriptions.
See also: [whisper.objc](https://github.com/ggerganov/whisper.cpp/tree/master/examples/whisper.objc).


**Explain**

This implementation refers to [whisper.objc](https://github.com/ggerganov/whisper.cpp/tree/master/examples/whisper.objc) implementation ideas.

Real-time acquisition of recording data, conversion of data to whisper.cpp supported types, accumulation and storage.

Transfer all recorded data to whistler.cpp each time, and then return the overall result.

There is still a short distance to real-time audio processing.

**Usage**:

1. Select a model from the [whisper.cpp repository](https://github.com/ggerganov/whisper.cpp/tree/master/models).[^1]
2. Add the model to `whisper.swiftui.demo/Resources/models` **via Xcode**.
3. Select the "Release" [^2] build configuration under "Run", then deploy and run to your device.


**Note:** 

Pay attention to the folder path: `whisper.swiftui.demo/Resources/models` is the appropriate directory to place resources whilst `whisper.swiftui.demo/Models` is related to actual code.

**Test:**

It works in xcode 14.3.1 and IPhone 14 with iOS 16.4 Simulator.

[^1]: I recommend the tiny, base or small models for running on an iOS device.

[^2]: The `Release` build can boost performance of transcription. In this project, it also added `-O3 -DNDEBUG` to `Other C Flags`, but adding flags to app proj is not ideal in real world (applies to all C/C++ files), consider splitting xcodeproj in workspace in your own project.

![realtime](https://github.com/mpr0xy/whisper.swiftui/assets/6849642/05a3ecd1-938e-4390-b04f-ecb8330b86d3)
