import Flutter
import UIKit
import AVFoundation

@available(iOS 9.0, *)
public class SwiftAudioStreamsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    let engine = AVAudioEngine()
    private var outputFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16, sampleRate: 8000, channels: 1, interleaved: true)
    var actualSampleRate:Float64?; // this is the actual hardware sample rate the device is using/ this is the encoding/bit-depth the user wants
    var actualBitDepth:UInt32?; // this is the actual hardware bit-depth
    var BUFFER_SIZE = 4096;
    var floatBuffer1000ms = [Int16](repeating: 0,count:16000)
    var floatBuffer = [Int16](repeating: 0,count:800)
    var floatTemp = [Int16](repeating: 0,count:16000)
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "aaron.code.com/mic_stream_method_channel", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "aaron.code.com/mic_stream", binaryMessenger: registrar.messenger())
        let instance = SwiftAudioStreamsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            
            case "getSampleRate":
            result(self.actualSampleRate ?? 4096.0)
                break;
            case "getBitDepth":
                result(self.actualBitDepth ?? 0)
                break;
            case "getBufferSize":
                result(self.BUFFER_SIZE)
                break;
            default:
                result(FlutterMethodNotImplemented)
        }
    }
    


    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Switch for parsing commonFormat - Can abstract later
        let input = engine.inputNode
        let bus = 0
        let inputFormat = input.outputFormat(forBus: 0)
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat!)!


        input.installTap(onBus: bus, bufferSize: 1024, format: inputFormat) { (buffer, time) -> Void in
            var newBufferAvailable = true

            let inputCallback: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                if newBufferAvailable {
                    outStatus.pointee = .haveData
                    newBufferAvailable = false
                    return buffer
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }

            let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self.outputFormat!, frameCapacity: AVAudioFrameCount(self.outputFormat!.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate))!
            //let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self.outputFormat!, frameCapacity: AVAudioFrameCount(1024))!
            
//print("self.outputFormat!.sampleRate: \(AVAudioFrameCount(self.outputFormat!.sampleRate))")
//print("buffer.format.sampleRate: \(AVAudioFrameCount(buffer.format.sampleRate))")

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputCallback)
            assert(status != .error)

            //if (self.outputFormat?.commonFormat == AVAudioCommonFormat.pcmFormatInt16) {
                let values = UnsafeBufferPointer(start: convertedBuffer.int16ChannelData![0], count: Int(convertedBuffer.frameLength))
                let buffer = Array(values)
            //print("buffer: \(buffer)")
                
                buffer.enumerated().forEach{(index,value) in
                    self.floatBuffer[index] = buffer[index];
                }
            //print("floatBuffer: \(self.floatBuffer)")

            

/// buraya kadar gelen buffer ve floatBuffer verileri ok

            
//bu ara --> sorunlu!!!
            /*
            for i in(0...(self.floatBuffer.count - 1)).reversed() where i < self.floatTemp.count{
                self.floatTemp.remove(at: i)
            }
            self.floatTemp.append(contentsOf: self.floatBuffer)
             */
//buraya kadar --> sorunlu!!!
            self.floatTemp[(self.floatTemp.count-self.floatBuffer.count)...(self.floatTemp.count - 1)] = self.floatBuffer[0...(self.floatBuffer.count - 1)]
            // System.arraycopy(floatBuffer,0,floatTemp,floatTemp.length-floatBuffer.length,floatBuffer.length);

            //print("floatTemp: \(self.floatTemp)")


            var newList = self.floatTemp.suffix(self.floatBuffer1000ms.count - self.floatBuffer.count)
            //print("NEWLIST LENGTH 2: \(newList.count)")
            self.floatTemp[0...(newList.count - 1)] = newList

            
            
            self.floatBuffer1000ms = self.floatTemp;
            
            

            let convertData = UnsafeMutableRawPointer(mutating: self.floatBuffer1000ms)
            let data : Data = Data(bytesNoCopy: convertData, count: Int(self.floatBuffer1000ms.count), deallocator: .none)
                events(FlutterStandardTypedData(bytes: data))

        }

        try! engine.start()

        return nil

    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        return nil

    }
}

extension ContiguousBytes {
    func objects<T>() -> [T] { withUnsafeBytes { .init($0.bindMemory(to: T.self)) } }
    var uInt16Array: [UInt16] { objects() }
    var int32Array: [Int32] { objects() }
}

extension Array {
    var data: Data { withUnsafeBytes { .init($0) } }
}
