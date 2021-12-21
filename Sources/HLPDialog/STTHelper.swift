/*******************************************************************************
 * Copyright (c) 2014, 2016  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

import Foundation
import UIKit
import AVFoundation
import Speech


@objcMembers
open class STTHelper: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, SFSpeechRecognizerDelegate {
    
    fileprivate let speechRecognizer = SFSpeechRecognizer()!
    fileprivate var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    fileprivate var recognitionTask: SFSpeechRecognitionTask?
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    
    public var tts:TTSProtocol?
    public var delegate:DialogViewHelper?
    public var speaking:Bool = false
    public var recognizing:Bool = false
    public var paused:Bool = true
    public var restarting:Bool = true
    var last_actions: [([String],(String, UInt64)->Void)]?
    var last_failure:(NSError)->Void = {arg in}
    var last_timeout:()->Void = { () in}
    var last_text: String = ""

    var stopstt:()->()
    let waitDelay = 0.0

    var pwCaptureSession:AVCaptureSession? = nil
    var audioDataQueue:DispatchQueue? = nil
    
    var timeoutTimer:Timer? = nil
    var timeoutDuration:TimeInterval = 20.0

    var resulttimer:Timer? = nil
    var resulttimerDuration:TimeInterval = 1.0

    var unknownErrorCount = 0
    public var useRawError = false
    
    override public init() {
        self.stopstt = {}
        self.audioDataQueue = DispatchQueue(label: "hulop.conversation", attributes: [])
        super.init()

        speechRecognizer.delegate = self
        SFSpeechRecognizer.requestAuthorization { authStatus in
            print(authStatus);
        }

        // need to set AVAudioSession before
        let audioSession:AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            NSLog("Audio session error")
        }

        self.initPWCaptureSession()
    }

    func createError(_ message:String) -> NSError{
        let domain = "swift.sttHelper"
        let code = -1
        let userInfo = [NSLocalizedDescriptionKey:message]
        return NSError(domain:domain, code: code, userInfo:userInfo)
    }

    var pwCapturingStarted: Bool = false
    var pwCapturingIgnore: Bool = false
    fileprivate func initPWCaptureSession(){//alternative
        if nil == self.pwCaptureSession{
            self.pwCaptureSession = AVCaptureSession()
            if let captureSession = self.pwCaptureSession{
                captureSession.automaticallyConfiguresApplicationAudioSession = false
                if let microphoneDevice = AVCaptureDevice.default(for: .audio) {
                    let microphoneInput = try? AVCaptureDeviceInput(device: microphoneDevice)
                    if(captureSession.canAddInput(microphoneInput!)){
                        captureSession.addInput(microphoneInput!)

                        let adOutput = AVCaptureAudioDataOutput()
                        adOutput.setSampleBufferDelegate(self, queue: self.audioDataQueue)
                        if captureSession.canAddOutput(adOutput){
                            captureSession.addOutput(adOutput)
                        }
                    }
                }
            }
        }

        if !pwCapturingStarted {
            self.pwCaptureSession?.startRunning()
        }
    }

    fileprivate func startPWCaptureSession(){//alternative
        pwCapturingIgnore = false
    }

    fileprivate func stopPWCaptureSession(){
        pwCapturingIgnore = true
    }

    open func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // append buffer to recognition request
        if !pwCapturingIgnore {
            recognitionRequest?.appendAudioSampleBuffer(sampleBuffer)
        }
        if !pwCapturingStarted {
            NSLog("Recording started")
        }
        pwCapturingStarted = true

        // get raw data and calcurate the power
        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout.stride(ofValue: audioBufferList),
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer)
        guard let data = audioBufferList.mBuffers.mData else {
            return
        }
        let actualSampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
        let ptr = data.bindMemory(to: Int16.self, capacity: actualSampleCount)
        let buf = UnsafeBufferPointer(start: ptr, count: actualSampleCount)
        let array = Array(buf)

        // check power in 256 sample window (62.5Hz @ 16000 sample per sec) and
        // but buffer is bigger than this so set power level with delay
        let setMaxPowerLambda:(Float, Double) -> Void = {power, delay in
            DispatchQueue.main.asyncAfter(deadline: .now()+delay) {
                self.delegate?.setMaxPower(power)
            }
        }

        var count = 0
        let windowSize = 256
        var ave:Float = 0
        for a in array {
            count += 1
            if count % windowSize == 0 {
                // max is 110db
                let power = 110 + (log10((ave+1) / Float(windowSize)) - log10(32768))*20
                setMaxPowerLambda(power, Double(count) / 16000.0)
                ave = 0
            }
            ave += Float(abs(a))
        }
    }

    func startRecognize(_ actions: [([String],(String, UInt64)->Void)], failure: @escaping (NSError)->Void,  timeout: @escaping ()->Void){
        self.paused = false
        
        self.last_timeout = timeout
        self.last_failure = failure
                        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest!.shouldReportPartialResults = true
        last_text = ""
        NSLog("Start recognizing")
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!, resultHandler: { [weak self] (result, e) in
            guard let weakself = self else {
                return
            }
            let complete:()->Void = {
                if weakself.last_text.count == 0 { return }
                for action in actions {
                    let patterns = action.0
                    for pattern in patterns {
                        if weakself.checkPattern(pattern, weakself.last_text) {
                            NSLog("Matched pattern = \(pattern)")
                            weakself.endRecognize();
                            weakself.delegate?.recognize()
                            return (action.1)(weakself.last_text, 0)
                        }
                    }
                }
            }

            if e != nil {
                weakself.stoptimer()
                guard let error:NSError = e as NSError? else {
                    print(e!)
                    weakself.endRecognize()
                    timeout()
                    return;
                }

                let code = error.code
                if code == 203 { // Empty recognition
                    weakself.endRecognize();
                    weakself.delegate?.recognize()
                    timeout()
                } else if code == 209 || code == 216 || code == 1700 || code == 301 {
                    // noop
                    // 209 : trying to stop while starting
                    // 216 : terminated by manual
                    // 1700: background
                    complete()
                } else if code == 4 {
                    weakself.endRecognize(); // network error
                    let newError = weakself.createError(NSLocalizedString("checkNetworkConnection", tableName: nil, bundle: Bundle.module, value: "", comment:""))
                    failure(newError)
                } else {
                    weakself.endRecognize()
                    if weakself.useRawError {
                        failure(error) // unknown error
                    } else {
                        let newError = weakself.createError(NSLocalizedString("unknownError\(weakself.unknownErrorCount)", tableName: nil, bundle: Bundle.module, value: "", comment:""))
                        failure(newError)
                        weakself.unknownErrorCount = (weakself.unknownErrorCount + 1) % 2
                    }
                }
                return;
            }
            
            guard let recognitionTask = weakself.recognitionTask else {
                return;
            }
            
            guard recognitionTask.isCancelled == false else {
                return;
            }
            
            guard let result = result else {
                return;
            }
            weakself.stoptimer();
            
            weakself.last_text = result.bestTranscription.formattedString;

            weakself.resulttimer = Timer.scheduledTimer(withTimeInterval: weakself.resulttimerDuration, repeats: false, block: { (timer) in
                weakself.endRecognize()
            })
            
            let str = weakself.last_text
            let isFinal:Bool = result.isFinal;
            let length:Int = str.count
            NSLog("Result = \(str), Length = \(length), isFinal = \(isFinal)");
            if (str.count > 0) {
                weakself.delegate?.showText(str);
                if isFinal{
                    complete()
                }
            }else{
                if isFinal{
                    weakself.delegate?.showText("?")
                }
            }
        })
        self.stopstt = {
            self.recognitionTask?.cancel()
            if self.resulttimer != nil{
                self.resulttimer?.invalidate()
                self.resulttimer = nil;
            }
            self.stopstt = {}
        }
        
        self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: self.timeoutDuration, repeats: false, block: { (timer) in
            self.endRecognize()
            timeout()
        })
        
        self.restarting = false
        self.recognizing = true
    }
    
    func stoptimer(){
        if self.resulttimer != nil{
            self.resulttimer?.invalidate()
            self.resulttimer = nil
        }
        if self.timeoutTimer != nil {
            self.timeoutTimer?.invalidate()
            self.timeoutTimer = nil
        }
    }
    
    public func listen(_ actions: [([String],(String, UInt64)->Void)], selfvoice: String?, speakendactions:[((String)->Void)]?,avrdelegate:AVAudioRecorderDelegate?, failure:@escaping (NSError)->Void, timeout:@escaping ()->Void) {
        
        if (speaking) {
            NSLog("TTS is speaking so this listen is eliminated")
            return
        }
        NSLog("Listen \"\(selfvoice ?? "")\" \(actions)")
        self.last_actions = actions

        self.stoptimer()
        delegate?.speak()
        delegate?.showText(" ")

        self.tts?.speak(selfvoice) {
            if (!self.speaking) {
                return
            }
            self.speaking = false
            if speakendactions != nil {
                for act in speakendactions!{
                    (act)(selfvoice!)
                }
            }

            self.tts?.vibrate()
            self.tts?.playVoiceRecoStart()

            DispatchQueue.main.asyncAfter(deadline: .now()+self.waitDelay) {
                self.startPWCaptureSession()//alternative
                self.startRecognize(actions, failure: failure, timeout: timeout)

                self.delegate?.showText(NSLocalizedString("SPEAK_NOW", tableName: nil, bundle: Bundle.module, value: "", comment:"Speak Now!"),color: UIColor.black)
                self.delegate?.listen()
            }

        }
        self.speaking = true
    }
    
    func now() -> Double {
        return Date().timeIntervalSince1970
    }
    
    public func prepare() {
    }
    
    public func disconnect() {
        self.tts?.stop()
        self.speaking = false
        self.recognizing = false
        self.pwCaptureSession?.stopRunning()
        self.stopstt()
        self.stoptimer()
    }
    
    public func endRecognize() {
        tts?.stop()
        self.speaking = false
        self.recognizing = false
        self.stopPWCaptureSession()
        self.stopstt()
        self.stoptimer()
    }
    
    public func restartRecognize() {
        self.paused = false;
        self.restarting = true;
        if let actions = self.last_actions {
            self.tts?.vibrate()
            self.tts?.playVoiceRecoStart()

            DispatchQueue.main.asyncAfter(deadline: .now()+self.waitDelay) {
                self.startPWCaptureSession()
                self.startRecognize(actions, failure:self.last_failure, timeout:self.last_timeout)
            }
        }
    }

    func checkPattern(_ pattern: String?, _ text: String?) -> Bool {
        if text != nil {
            do {
                var regex:NSRegularExpression?;
                try regex = NSRegularExpression(pattern: pattern!, options: NSRegularExpression.Options.caseInsensitive)
                if (regex?.matches(in: text!, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSMakeRange(0, (text?.count)!)).count)! > 0 {
                    return true
                }
            } catch {
                
            }
        }
        
        return false
    }
}
