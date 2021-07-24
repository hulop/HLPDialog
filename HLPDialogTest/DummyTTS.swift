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
 
import UIKit
import HLPDialog
import AVFoundation

class DummyTTS: NSObject, TTSProtocol, AVSpeechSynthesizerDelegate {
    static let shared = DummyTTS()

    var map: [String: ()->Void] = [:]
    let synthe = AVSpeechSynthesizer()

    func speak(_ text:String?, callback: @escaping ()->Void) {
        guard let text = text else {
            return callback()
        }

        synthe.delegate = self
        let u = AVSpeechUtterance(string: text)
        map[text] = callback
        NSLog("speech started: "+text)
        synthe.speak(u)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        NSLog("speech finished: "+utterance.speechString)
        if let callback = map[utterance.speechString] {
            callback()
        }
        synthe.stopSpeaking(at: .immediate)
    }
    
    func stop() {
        synthe.stopSpeaking(at: .word)
    }

    func stop(_ immediate: Bool) {
        synthe.stopSpeaking(at: .immediate)
    }
    
    func vibrate() {
        
    }
    
    func playVoiceRecoStart() {
        
    }
}
