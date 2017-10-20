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

class ViewController: UIViewController, DialogViewDelegate {
    
    var dialogHelper:DialogViewHelper?
    let config = ["conv_server": "hulop-conversation.au-syd.mybluemix.net",
                  "conv_api_key": "nd2tLsqQCnppRDsD",
                  "conv_client_id": "dummy"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(dialogStatusChanged), name: DialogManager.DIALOG_AVAILABILITY_CHANGED_NOTIFICATION, object: nil)
        
        DialogManager.sharedManager().config = config;
        // Do any additional setup after loading the view, typically from a nib.
        
        dialogHelper = DialogViewHelper()
        let scale:CGFloat = 0.75
        let size = (113*scale)/2
        let x = size+8
        let y = self.view.bounds.size.height - (size+8) 
        if let dh = dialogHelper {
            dh.subColor = UIColor.black.cgColor
            dh.mainColor = UIColor.green.cgColor
            dh.scale = scale
            dh.inactive()
            dh.setup(self.view, position:CGPoint(x: x, y: y))
            dh.delegate = self
            self.updateView()
        }
        var count = 0
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { (timer) in
            if let dh = self.dialogHelper{
                switch(count) {
                case 0:
                    dh.inactive()
                    break
                case 1:
                    dh.speak()
                    break
                case 2:
                    dh.listen()
                    break
                case 3:
                    dh.recognize()
                    break
                case 4:
                    dh.reset()
                    break
                default:
                    break
                }
            }
            count = (count+1)%5
        }
        
    }
    
    func updateView() {
        if let dh = dialogHelper {
            dh.helperView.isHidden = !DialogManager.sharedManager().isAvailable
            dh.recognize()
        }
        
    }
    
    @objc func dialogStatusChanged(note:NSNotification) {
        self.updateView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - DialogViewDelegate

    func dialogViewTapped() {
        let dialogView = DialogViewController()
        dialogView.tts = DummyTTS()
        dialogView.baseHelper = dialogHelper
        self.navigationController?.pushViewController(dialogView, animated: true)
    }

}

