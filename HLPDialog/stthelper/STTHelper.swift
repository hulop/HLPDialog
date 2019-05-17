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
    var listeningStart:Double = 0
    var avePower:Double = 0
    var aveCount:Int64 = 0
    var stopstt:()->()
    
    var pwCaptureSession:AVCaptureSession? = nil
    var audioDataQueue:DispatchQueue? = nil
    
    var arecorder:AVAudioRecorder? = nil
    var timeoutTimer:Timer? = nil
    var timeoutDuration:TimeInterval = 20.0
    var ametertimer:Timer? = nil
    var resulttimer:Timer? = nil
    var resulttimerDuration:TimeInterval = 1.0
    var confidenceFilter = 0.2
    var executeFilter = 0.3
    var hesitationPrefix = "D_"
    var unknownErrorCount = 0
    public var useRawError = false
    
    override public init() {
        self.stopstt = {}
        self.audioDataQueue = DispatchQueue(label: "hulop.conversation", attributes: [])
        super.init()
        self.initAudioRecorder()

        speechRecognizer.delegate = self
        SFSpeechRecognizer.requestAuthorization { authStatus in
            print(authStatus);
        }
    }
    fileprivate func initAudioRecorder(){
        let doc = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
        var url = URL(fileURLWithPath: doc)
        url = url.appendingPathComponent("recordTest.caf")
        let recsettings:[String:AnyObject] = [
            AVFormatIDKey: Int(kAudioFormatAppleIMA4) as AnyObject,
            AVSampleRateKey:44100.0 as AnyObject,
            AVNumberOfChannelsKey:2 as AnyObject,
            AVEncoderBitRateKey:12800 as AnyObject,
            AVLinearPCMBitDepthKey:16 as AnyObject,
            AVEncoderAudioQualityKey:AVAudioQuality.max.rawValue as AnyObject
        ]
        
        self.arecorder = try? AVAudioRecorder(url:url,settings:recsettings)
    }
    var frecCaptureSession:AVCaptureSession? = nil
    var frecDataQueue:DispatchQueue? = nil
    func startRecording(_ input: AVCaptureDeviceInput){
        self.stopRecording()
        self.frecCaptureSession = AVCaptureSession()
        if frecCaptureSession!.canAddInput(input){
            frecCaptureSession!.addInput(input)
        }
    }
    func stopRecording(){
        if self.frecCaptureSession != nil{
            self.frecCaptureSession?.stopRunning()
            for output in self.frecCaptureSession!.outputs{
                self.frecCaptureSession?.removeOutput(output )
            }
            for input in self.frecCaptureSession!.inputs{
                self.frecCaptureSession?.removeInput(input )
            }
            self.frecCaptureSession = nil
        }
    }
    
    func createError(_ message:String) -> NSError{
        let domain = "swift.sttHelper"
        let code = -1
        let userInfo = [NSLocalizedDescriptionKey:message]
        return NSError(domain:domain, code: code, userInfo:userInfo)
    }
    
    fileprivate func startPWCaptureSession(){//alternative
        if nil == self.pwCaptureSession{
            self.pwCaptureSession = AVCaptureSession()
            if let captureSession = self.pwCaptureSession{
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
        self.pwCaptureSession?.startRunning()
    }
    fileprivate func stopPWCaptureSession(){
        self.pwCaptureSession?.stopRunning()
    }

    open func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        recognitionRequest?.appendAudioSampleBuffer(sampleBuffer)                
        
        let channels = connection.audioChannels
        var peak:Float = 0;
        for chnl in channels{
            peak = (chnl as AnyObject).averagePowerLevel
        }
        DispatchQueue.main.async{
            self.delegate?.setMaxPower(peak + 110)
        }
    }
    func startAudioRecorder(){
        self.stopAudioRecorder()
        
        self.arecorder?.record()
    }
    func stopAudioRecorder(){
        self.arecorder?.stop()
    }
    
    func startAudioMetering(_ delegate: AVAudioRecorderDelegate?){
        self.stopAudioMetering()
        if let delegate = delegate{
            self.arecorder?.delegate = delegate
        }
        self.arecorder?.isMeteringEnabled = true
        self.startAudioRecorder()
        self.ametertimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(STTHelper.onamUpdate),userInfo:nil, repeats:true)
        self.ametertimer?.fire()
    }
    @objc func onamUpdate(){
        self.arecorder?.updateMeters()
        if let ave = self.arecorder?.averagePower(forChannel: 0){
            self.delegate?.setMaxPower(ave + 120)
            //            print(ave)
        }
    }
    func stopAudioMetering(){
        if self.ametertimer != nil{
            self.arecorder?.isMeteringEnabled = false
            self.ametertimer?.invalidate()
            self.ametertimer = nil
        }
        self.stopAudioRecorder()
    }
    
    func startRecognize(_ actions: [([String],(String, UInt64)->Void)], failure: @escaping (NSError)->Void,  timeout: @escaping ()->Void){
        self.paused = false
        
        let audioSession:AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.record)
            try audioSession.setActive(true)
        } catch {
        }
        
        self.last_timeout = timeout
        self.last_failure = failure
                        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest!.shouldReportPartialResults = true
        last_text = ""
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
                } else if code == 209 || code == 216 || code == 1700 {
                    // noop
                    // 209 : trying to stop while starting
                    // 216 : terminated by manual
                    // 1700: background
                    complete()
                } else if code == 4 {
                    weakself.endRecognize(); // network error
                    let newError = weakself.createError(NSLocalizedString("checkNetworkConnection", tableName: nil, bundle: Bundle(for: type(of: self) as! AnyClass), value: "", comment:""))
                    failure(newError)
                } else {
                    weakself.endRecognize()
                    if weakself.useRawError {
                        failure(error) // unknown error
                    } else {
                        let newError = weakself.createError(NSLocalizedString("unknownError\(weakself.unknownErrorCount)", tableName: nil, bundle: Bundle(for: type(of: self) as! AnyClass), value: "", comment:""))
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
    
    internal func _setTimeout(_ delay:TimeInterval, block:@escaping ()->Void) -> Timer {
        return Timer.scheduledTimer(timeInterval: delay, target: BlockOperation(block: block), selector: #selector(Operation.main), userInfo: nil, repeats: false)
    }
    
    public func listen(_ actions: [([String],(String, UInt64)->Void)], selfvoice: String?, speakendactions:[((String)->Void)]?,avrdelegate:AVAudioRecorderDelegate?, failure:@escaping (NSError)->Void, timeout:@escaping ()->Void) {
        
        if (speaking) {
            NSLog("TTS is speaking so this listen is eliminated")
            return
        }
        NSLog("Listen \(String(describing: selfvoice)) \(actions)")
        self.last_actions = actions

        self.stoptimer()
        delegate?.speak()
        delegate?.showText(" ")
        tts?.speak(selfvoice) {
            if (!self.speaking) {
                return
            }
            self.speaking = false
            if speakendactions != nil {
                for act in speakendactions!{
                    (act)(selfvoice!)
                }
            }
            self.listeningStart = self.now()

            let delay = 0.4
            self.tts?.vibrate()
            self.tts?.playVoiceRecoStart()
            
            _ = self._setTimeout(delay, block: {
                self.startPWCaptureSession()//alternative
                self.startRecognize(actions, failure: failure, timeout: timeout)
                
                self.delegate?.showText(NSLocalizedString("SPEAK_NOW", tableName: nil, bundle: Bundle(for: type(of: self)), value: "", comment:"Speak Now!"))
                self.delegate?.listen()
            })
            
        }
        speaking = true
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
        self.stopAudioMetering()
        self.arecorder?.stop()
        self.stopPWCaptureSession()
        self.stopstt()
        self.stoptimer()

        let avs:AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try avs.setCategory(AVAudioSession.Category.soloAmbient)
            try avs.setActive(true)
        } catch {
        }
    }
    
    public func endRecognize() {
        tts?.stop()
        self.speaking = false
        self.recognizing = false
        self.stopAudioMetering()
        self.arecorder?.stop()
        self.stopPWCaptureSession()
        self.stopstt()
        self.stoptimer()

        let avs:AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try avs.setCategory(AVAudioSession.Category.soloAmbient)
            try avs.setActive(true)
        } catch {
        }
    }
    
    public func restartRecognize() {
        self.paused = false;
        self.restarting = true;
        if let actions = self.last_actions {
            let delay = 0.4
            self.tts?.vibrate()
            self.tts?.playVoiceRecoStart()
            
            _ = self._setTimeout(delay, block: {
                self.startPWCaptureSession()
                self.startRecognize(actions, failure:self.last_failure, timeout:self.last_timeout)
            })
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
