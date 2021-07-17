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
import RestKit
import AssistantV1

var standardError = FileHandle.standardError

extension FileHandle : TextOutputStream {
    public func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.write(data)
    }
}

class servicecred{
    internal let url:String
    internal let user:String
    internal let pass:String
    init(_url:String, _user:String, _pass:String){
        self.url = _url
        self.user = _user
        self.pass = _pass
    }
}

protocol ControlViewDelegate: AnyObject {
    func elementFocusedByVoiceOver()
    func actionPerformedByVoiceOver()
}

@objcMembers
open class DialogViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, LocalContextDelegate, ControlViewDelegate, DialogViewDelegate {
    deinit {
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self)
        DialogManager.sharedManager().isAvailable = true
    }
    open var tts:TTSProtocol? = nil
    open var baseHelper:DialogViewHelper? = nil
    
    var imageView: UIImageView? = nil
    var tableView: UITableView? = nil
    var controlView: ControlView? = nil
    var conversation_id:String? = nil
    var client_id:Int? = nil
    open var root: UIViewController? = nil
    //let tintColor: UIColor = UIColor(red: 0, green: 0.478431, blue: 1, alpha: 1)
    var isDeveloperMode: Bool = false

    
    fileprivate var _stt:STTHelper? = nil
    
    let conv_devicetype:String = UIDevice.current.systemName + "_" + UIDevice.current.systemVersion
    let conv_deviceid:String = (UIDevice.current.identifierForVendor?.uuidString)!
    var conv_context:Context? = nil
    var conv_server:String? = nil
    var conv_api_key:String? = nil
    var conv_client_id:String? = nil
    let conv_navigation_url = "navcog3://start_navigation/"
    let conv_context_local:LocalContext = LocalContext()
    var conv_started = false
    
    let defbackgroundColor:UIColor = UIColor(red: CGFloat(221/255.0), green: CGFloat(222/255.0), blue: CGFloat(224/255.0), alpha:1.0)
    let blue:UIColor = UIColor(red: CGFloat(50/255.0), green: CGFloat(92/255.0), blue: CGFloat(128/255.0), alpha:1.0)
    let white:UIColor = UIColor(red: CGFloat(244/255.0), green: CGFloat(244/255.0), blue: CGFloat(236/255.0), alpha:1.0)
    let black:UIColor = UIColor(red: CGFloat(65/255.0), green: CGFloat(70/255.0), blue: CGFloat(76/255.0), alpha:1.0)
    
    var tableData:[Dictionary<String,Any>]!
    var heightLeftCell: CustomLeftTableViewCell = CustomLeftTableViewCell()
    var heightRightCell: CustomRightTableViewCell = CustomRightTableViewCell()
    
    open var dialogViewHelper: DialogViewHelper = DialogViewHelper()
    var cancellable = false
    
    
    /*
    let ttslock:NSLock = NSLock()
    fileprivate func getTts() -> TTSProtocol{
        self.ttslock.lock()
        defer{self.ttslock.unlock()}
        if let tts = self.tts{
            return tts
        }else{
            self.tts = DefaultTTS()
            return self.tts!
        }
    }
    */
    
    let sttlock:NSLock = NSLock()
    fileprivate func getStt() -> STTHelper{
        self.sttlock.lock()
        defer{self.sttlock.unlock()}
        if let stt = self._stt{
            return stt
        }else{
            self._stt = STTHelper()
            self._stt!.tts = self.tts;
            self._stt!.prepare()
            self._stt!.useRawError = self.isDeveloperMode
            return self._stt!
        }
    }
    internal func startConversation(){
        self.initConversationConfig()//override with local setting
        self.conv_context_local.verifyPrivacy()
    }
    override open func viewDidLoad() {
        super.viewDidLoad()
        print(Date(), #function, #line)
        self.conv_context_local.delegate = self
        _ = self.getStt()
        self.conv_context = nil
        self.tableData = []
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(pauseConversation), name: DialogManager.REQUEST_DIALOG_PAUSE, object: nil)
        nc.addObserver(self, selector: #selector(requestDialogEnd), name: DialogManager.REQUEST_DIALOG_END, object: nil)
        nc.addObserver(self, selector: #selector(requestDialogAction), name: DialogManager.REQUEST_DIALOG_ACTION, object: nil)

        resetConversation()
    }
    
    internal func updateView() {
    }

    override public func viewWillAppear(_ animated: Bool) {
        self.updateView()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        print(Date(), #function, #line)
        if !UIAccessibility.isVoiceOverRunning {
            restartConversation()
            DialogManager.sharedManager().isActive = true
        } else {
            _ = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(start), userInfo: nil, repeats: false)
        }
    }

    internal func start() {
        restartConversation()
        DialogManager.sharedManager().isActive = true
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        resetConversation()
        DialogManager.sharedManager().isActive = false
        self.updateView()
    }
    
    public func showNoSpeechRecoAlert() {
        let bundle = Bundle.module
        
        let title = NSLocalizedString("NoSpeechRecoAccessAlertTitle", tableName: nil, bundle: bundle, value: "", comment:"");
        let message = NSLocalizedString("NoSpeechRecoAccessAlertMessage", tableName: nil, bundle: bundle, value: "", comment:"");
        let setting = NSLocalizedString("SETTING", tableName: nil, bundle: bundle, value: "", comment:"");
        let cancel = NSLocalizedString("CANCEL", tableName: nil, bundle: bundle, value: "", comment:"");
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: setting, style: UIAlertAction.Style.default, handler: { (action) in
            let url = URL(string:UIApplication.openSettingsURLString)
            UIApplication.shared.open(url!, options:[:], completionHandler: { (success) in
            })
        }))
        alert.addAction(UIAlertAction(title: cancel, style: UIAlertAction.Style.default, handler: { (action) in
        }))
        DispatchQueue.main.async(execute: {
            self.present(alert, animated: true, completion: {
            })
        })
        cancellable = true
        self.updateView()
        
        self.tableData.append(["name": NSLocalizedString("Error", tableName: nil, bundle: bundle, value: "", comment:"") as AnyObject, "type": 1 as AnyObject,  "image": "conversation.png" as AnyObject, "message": message as AnyObject])
        self.refreshTableView()
    }
    
    public func showNoAudioAccessAlert(){
        let bundle = Bundle.module
        
        let title = NSLocalizedString("NoAudioAccessAlertTitle", tableName: nil, bundle: bundle, value: "", comment:"");
        let message = NSLocalizedString("NoAudioAccessAlertMessage", tableName: nil, bundle: bundle, value: "", comment:"");
        let setting = NSLocalizedString("SETTING", tableName: nil, bundle: bundle, value: "", comment:"");
        let cancel = NSLocalizedString("CANCEL", tableName: nil, bundle: bundle, value: "", comment:"");

        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: setting, style: UIAlertAction.Style.default, handler: { (action) in
            let url = URL(string:UIApplication.openSettingsURLString)
            UIApplication.shared.open(url!, options:[:], completionHandler: { (success) in
            })
        }))
        alert.addAction(UIAlertAction(title: cancel, style: UIAlertAction.Style.default, handler: { (action) in
        }))
        DispatchQueue.main.async(execute: {
            self.present(alert, animated: true, completion: { 
            })
        })
        cancellable = true
        self.updateView()
        
        self.tableData.append(["name": NSLocalizedString("Error", tableName: nil, bundle: bundle, value: "", comment:"") as AnyObject, "type": 1 as AnyObject,  "image": "conversation.png" as AnyObject, "message": message as AnyObject])
        self.refreshTableView()
    }
    
    @objc internal func requestDialogEnd() {
        if cancellable {
            _ = self.navigationController?.popToRootViewController(animated: true)
        } else {
            //NavSound.sharedInstance().playFail()
        }
    }

    @objc internal func requestDialogAction() {
        self.dialogViewTapped()
    }
    
    internal func resetConversation(){
        DialogManager.sharedManager().isAvailable = false
        self.getStt().disconnect()
        _stt?.delegate = nil
        _stt = nil
        tts = nil
        self.conv_context_local.delegate = nil
        self.conv_context = nil
        self.tableData = []
        if let tableview = self.tableView{
            tableview.removeFromSuperview()
            self.tableView!.delegate = self
            self.tableView!.dataSource = self
            self.tableView = nil
        }
        self.dialogViewHelper.reset()
        self.dialogViewHelper.removeFromSuperview()
        self.dialogViewHelper.delegate = nil
    }
    
    internal func restartConversation(){
        print("restartConversation");
        DispatchQueue.main.async {
            self.conv_context_local.delegate = self
            self.getStt().prepare()
            self.initDialogView()
            self.conv_started = false
            self.startConversation()
        }
    }
    
    @objc internal func pauseConversation() {
        let bundle = Bundle.module
        
        let stt = self.getStt()
        if (stt.recognizing) {
            print("pause stt")
            stt.endRecognize()
            stt.paused = true
            stt.delegate?.showText(NSLocalizedString("PAUSING", tableName: nil, bundle: bundle, value: "", comment:"Pausing"));
            stt.delegate?.inactive()
        } else if(stt.speaking) {
            print("stop tts")
            stt.speaking = false
            stt.tts?.stop() // do not use "true" flag beacus it causes no-speaking problem.
            stt.delegate?.showText(NSLocalizedString("PAUSING", tableName: nil, bundle: bundle, value: "", comment:"Pausing"));
            stt.delegate?.inactive()
        }
    }
    
    public func onContextChange(_ context:LocalContext){
        if !self.conv_started{
            self.conv_started = true
            self.sendMessage("")
        }
    }
    
    fileprivate func initConversationConfig(){
        if let defs = DialogManager.sharedManager().config {
            let server = defs["conv_server"]
            if let _server = server as? String {
                if !_server.isEmpty {
                    self.conv_server = _server
                }
            }
            let key = defs["conv_api_key"]
            if let _key = key as? String {
                if !_key.isEmpty {
                    self.conv_api_key = _key
                }
            }
            let str = defs["conv_client_id"]
            if let _str = str as? String {
                if  !_str.isEmpty {
                    self.conv_client_id = _str
                }
            }
        }
    }

    class NoVoiceTableView: UITableView {
        override var accessibilityElementsHidden: Bool {
            set {}
            get { return true }
        }
    }
    
    class ControlView: UIView {
        weak var delegate:ControlViewDelegate?
        override var isAccessibilityElement: Bool {
            set {}
            get { return true }
        }
        override var accessibilityLabel: String? {
            set {}
            get {
                return NSLocalizedString("DialogStart", tableName: nil, bundle: Bundle.module, value: "", comment: "")
            }
        }
        override var accessibilityHint: String? {
            set {}
            get {
                return NSLocalizedString("DialogStartHint", tableName: nil, bundle: Bundle.module, value: "", comment: "")
            }
        }
        override var accessibilityTraits: UIAccessibilityTraits {
            set {}
            get {
                return UIAccessibilityTraits.button
            }
        }
        override func accessibilityElementDidBecomeFocused() {
            if delegate != nil {
                delegate!.elementFocusedByVoiceOver()
            }
        }
        override func accessibilityActivate() -> Bool {
            if delegate != nil {
                delegate!.actionPerformedByVoiceOver()
            }
            return true
        }
    }
    fileprivate func initDialogView(){
        self.view.backgroundColor = defbackgroundColor
       if(nil == self.tableView){
            // chat messages
            self.tableView = NoVoiceTableView()
            self.tableView!.register(CustomLeftTableViewCell.self, forCellReuseIdentifier: "CustomLeftTableViewCell")
            self.tableView!.register(CustomRightTableViewCell.self, forCellReuseIdentifier: "CustomRightTableViewCell")
            self.tableView!.register(CustomLeftTableViewCellSpeaking.self, forCellReuseIdentifier: "CustomLeftTableViewCellSpeaking")
            self.tableView!.delegate = self
            self.tableView!.dataSource = self
            self.tableView!.separatorColor = UIColor.clear
            self.tableView?.backgroundColor = defbackgroundColor
            //        self.tableView!.layer.zPosition = -1
            
            // mic button and dictated text label
            self.controlView = ControlView()
            self.controlView!.delegate = self
            self.controlView!.frame = self.view!.frame
            // show mic button on controlView
            let pos = CGPoint(x: self.view.bounds.width/2, y: self.view.bounds.height - 120)
            if let dh = baseHelper {
                dialogViewHelper.mainColor = dh.mainColor
                dialogViewHelper.subColor = dh.subColor
                dialogViewHelper.backgroundColor = dh.backgroundColor
            }
            dialogViewHelper.setup(self.controlView!, position:pos, tapEnabled: true)
            dialogViewHelper.delegate = self
            
            // add controlView first
            self.view.addSubview(controlView!)
            self.view.addSubview(tableView!)
        }
        
        self.resizeTableView()
    }
    func elementFocusedByVoiceOver() {
        let stt = self.getStt()

        stt.tts?.stop(false)
        stt.disconnect()
        if !stt.paused {
            self.tts?.vibrate()
            self.tts?.playVoiceRecoStart()
        }
        stt.paused = true
        stt.delegate?.showText(NSLocalizedString("PAUSING", tableName: nil, bundle: Bundle.module, value: "", comment:"Pausing"));
        stt.delegate?.inactive()
    }
    func actionPerformedByVoiceOver() {
        let stt = self.getStt()
        if(stt.paused){
            print("restart stt")
            stt.restartRecognize()
            stt.delegate?.showText(NSLocalizedString("SPEAK_NOW", tableName: nil, bundle: Bundle.module, value: "", comment:"Speak Now!"));
            stt.delegate?.listen()
            UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: self.navigationItem.leftBarButtonItem)
        }
    }
    
    fileprivate func resizeTableView(){
        if(nil == self.tableView){
            return
        }

        let statusBarHeight: CGFloat = UIApplication.shared.statusBarFrame.height + 40
        let txheight = self.dialogViewHelper.helperView.bounds.height + self.dialogViewHelper.label.bounds.height
        
        let displayWidth: CGFloat = self.view.frame.width
        let displayHeight: CGFloat = self.view.frame.height
        self.tableView!.frame = CGRect(x:0, y:statusBarHeight, width:displayWidth, height:displayHeight - statusBarHeight - txheight)
    }
    fileprivate func initImageView(){
        let image1:UIImage? = UIImage(named:"Dashboard.PNG")
        
        self.imageView = UIImageView(frame:self.view.bounds)
        self.imageView!.image = image1
        
        self.view.addSubview(self.imageView!)
    }
    fileprivate func removeImageView(){
        self.imageView?.removeFromSuperview()
    }
    override public func viewDidLayoutSubviews() {
        self.resizeTableView()

    }
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        if self.tableData.count <= indexPath.row {
            return 0
        }
        
        let type:Int = self.tableData[indexPath.row]["type"] as! Int
        if 1 == type {
            return heightLeftCell.setData(tableView.frame.size.width - 20, data: self.tableData[indexPath.row])
        }
        else if 2 == type{
            return heightRightCell.setData(tableView.frame.size.width - 20, data: self.tableData[indexPath.row])
        }else{//3
            return self.heightLeftCell.setData(tableView.frame.size.width - 20, data: self.tableData[indexPath.row])
        }
    }
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        var type:Int = 1
        var data:[String:Any] = [:]
        if indexPath.row < self.tableData.count {
            data = self.tableData[indexPath.row]
            type = data["type"] as! Int
        }
        if 1 == type
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CustomLeftTableViewCell", for: indexPath) as! CustomLeftTableViewCell
            cell.backgroundColor = defbackgroundColor
            cell.fillColor = white
            cell.fontColor = black
            cell.strokeColor = blue
            _ = cell.setData(tableView.frame.size.width - 20, data: data)
            return cell
        }
        else if 2 == type
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CustomRightTableViewCell", for: indexPath) as! CustomRightTableViewCell
            cell.backgroundColor = defbackgroundColor
            cell.fillColor = blue
            cell.fontColor = white
            cell.strokeColor = blue
            _ = cell.setData(tableView.frame.size.width - 20, data: data)
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "CustomLeftTableViewCellSpeaking", for: indexPath) as! CustomLeftTableViewCellSpeaking
            cell.backgroundColor = defbackgroundColor
            cell.fillColor = white
            cell.fontColor = black
            cell.strokeColor = blue
            _ = cell.setData(tableView.frame.size.width - 20, data: data)
            return cell
        }
    }
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    internal func refreshTableView(_ dontscroll:Bool? = false){
        if(nil == self.tableView){
            return
        }
        DispatchQueue.main.async(execute: { [weak self] in
            if let weakself = self {
                weakself.tableView?.reloadData()
                if !dontscroll!{
                    DispatchQueue.main.async(execute: {
                        if(nil == weakself.tableView){
                            return
                        }
                        let nos = weakself.tableView!.numberOfSections
                        let nor = weakself.tableView!.numberOfRows(inSection: nos-1)
                        if nor > 0{
                            let lastPath:IndexPath = IndexPath(row:nor-1, section:nos-1)
                            weakself.tableView!.scrollToRow( at: lastPath , at: .bottom, animated: false)
                        }
                    })
                }
            }
        })
    }
    
    public func dialogViewTapped() {
        let bundle = Bundle.module
        
        let stt = self.getStt()
        if (stt.recognizing) {
            print("pause stt")
            stt.endRecognize()
            stt.paused = true
            stt.delegate?.showText(NSLocalizedString("PAUSING", tableName: nil, bundle: bundle, value: "", comment:"Pausing"));
            stt.delegate?.inactive()
            //NavSound.sharedInstance().playVoiceRecoPause()
        } else if(stt.speaking) {
            print("stop tts")
            stt.tts?.stop() // do not use "true" flag beacus it causes no-speaking problem.
            stt.delegate?.showText(NSLocalizedString("PAUSING", tableName: nil, bundle: bundle, value: "", comment:"Pausing"));
            stt.delegate?.inactive()
        } else if(stt.paused){
            print("restart stt")
            stt.restartRecognize()
            stt.delegate?.showText(NSLocalizedString("SPEAK_NOW", tableName: nil, bundle: bundle, value: "", comment:"Speak Now!"));
            stt.delegate?.listen()
        } else if(stt.restarting) {
            print("stt is restarting")
            // noop
        } else {
            stt.tts?.stop(false)
            stt.delegate?.inactive()
        }
    }
    
    internal func matches(_ txt: String, pattern:String)->[[String]]{
        let nsstr = txt as NSString
        var ret:[[String]] = []
        if let regex = try? NSRegularExpression(pattern: pattern, options:NSRegularExpression.Options()){
            let result = regex.matches(in: nsstr as String, options: NSRegularExpression.MatchingOptions(), range: NSMakeRange(0, nsstr.length)) 
            if 0 < result.count{
                for i in 0 ..< result.count {
                    var temp: [String] = []
                    for j in 0 ..< result[i].numberOfRanges{
                        temp.append(nsstr.substring(with: result[i].range(at: j)))
                    }
                    ret.append(temp)
                }
            }
        }
        return ret
    }
    
    internal func _setTimeout(_ delay:TimeInterval, block:@escaping ()->Void) -> Timer {
        return Timer.scheduledTimer(timeInterval: delay, target: BlockOperation(block: block), selector: #selector(Operation.main), userInfo: nil, repeats: false)
    }

    var inflight:Timer? = nil
    var agent_name = ""
    var lastresponse:MessageResponse? = nil
    internal func newresponse(_ orgres: MessageResponse?) {
        conv_context_local.welcome_shown()
        DispatchQueue.main.async(execute: { [weak self] in
            if let weakself = self {
                weakself.cancellable = true
                weakself.updateView()
            }
        })

        self.removeImageView()
        var resobj:MessageResponse? = orgres
        if resobj == nil{
            resobj = self.lastresponse
        }else{
            self.lastresponse = orgres
        }
        let restxt = resobj!.output.text.joined(separator: "\n")
        self.conv_context = resobj!.context
        
        guard let cc = self.conv_context else {
            return
        }

        guard let system = cc.system else {
            return
        }

        if system.additionalProperties["dialog_request_counter"] == nil {
            return
        }
        if case let JSON.int(dialog_request_counter)? = system.additionalProperties["dialog_request_counter"] {
            if dialog_request_counter > 1 {
                self.timeoutCount = 0
            }
        }

        if case let JSON.string(name)? = cc.additionalProperties["agent_name"] {
            agent_name = name
        }
        
        self.removeWaiting()
        self.tableData.append(["name": agent_name, "type": 1,  "image": "conversation.png", "message": restxt])
        self.refreshTableView()
        var postEndDialog:(()->Void)? = nil
        if case let JSON.boolean(fin)? = cc.additionalProperties["finish"] {
            if fin {
                postEndDialog = {
                    self.cancellable = true
                    self.updateView()

                    if self.root != nil {
                        _ = self.navigationController?.popToViewController(self.root!, animated: true)
                    } else {
                        _ = self.navigationController?.popToRootViewController(animated: true)
                    }
                    //UIApplication.shared.open(URL(string: self.conv_navigation_url + "")!, options: [:], completionHandler: nil)                    
                }
            }
        }
        if case let JSON.boolean(navi)? = cc.additionalProperties["navi"] {
            if navi {
                if case let JSON.object(dest_info)? = cc.additionalProperties["dest_info"] {
                    if case let JSON.string(nodes)? = dest_info["nodes"] {
                        var info:[String : Any] = ["toID": nodes]
                        if case let JSON.string(from)? = dest_info["from"] {
                            info["fromID"] = from
                        }
                        if cc.additionalProperties["use_stair"] != nil {
                            if case let JSON.boolean(use_stair)? = cc.additionalProperties["use_stair"] {
                                info["use_stair"] = use_stair
                            }
                        }
                        if cc.additionalProperties["use_elevator"] != nil {
                            if case let JSON.boolean(use_elevator)? = cc.additionalProperties["use_elevator"] {
                                info["use_elevator"] = use_elevator
                            }
                        }
                        if cc.additionalProperties["use_escalator"] != nil {
                            if case let JSON.boolean(use_escalator)? = cc.additionalProperties["use_escalator"] {
                                info["use_escalator"] = use_escalator
                            }
                        }
                        postEndDialog = { [weak self] in
                            if let weakself = self {
                                weakself.cancellable = true
                                weakself.updateView()

                                if weakself.root != nil {
                                    _ = weakself.navigationController?.popToViewController(weakself.root!, animated: true)
                                } else {
                                    _ = weakself.navigationController?.popToRootViewController(animated: true)
                                }                                

                                NotificationCenter.default.post(name: Notification.Name(rawValue:"request_start_navigation"),
                                                                object: weakself, userInfo: info)
                            }
                        }
                    }
                }
                if case let JSON.object(find_info)? = cc.additionalProperties["find_info"] {
                    var info:[String : Any] = [:]
                    if case let JSON.string(name)? = find_info["name"] {
                        info["name"] = name
                    }
                    postEndDialog = { [weak self] in
                        if let weakself = self {
                            weakself.cancellable = true
                            weakself.updateView()

                            if weakself.root != nil {
                                _ = weakself.navigationController?.popToViewController(weakself.root!, animated: true)
                            } else {
                                _ = weakself.navigationController?.popToRootViewController(animated: true)
                            }

                            NotificationCenter.default.post(name: Notification.Name(rawValue:"request_find_person"),
                                                            object: weakself, userInfo: info)
                        }
                    }
                }
            }
        }
        var speech = restxt
        if case let JSON.string(pron)? = cc.additionalProperties["output_pron"] {
            speech = pron
        }

        DispatchQueue.main.async(execute: { [weak self] in
            if let weakself = self {
                if let callback = postEndDialog {
                    weakself.endDialog(speech)
                    weakself.tts?.speak(speech) {
                        callback()
                    }
                }else{
                    weakself.startDialog(speech)
                }
            }
        })
    }
    internal func newmessage(_ msg:String){
        self.tableData.append(["name":"myself" as AnyObject, "type": 2 as AnyObject,
            "message":msg as AnyObject ])
        self.refreshTableView()
    }
    
    func removeWaiting() {
        if let timer = self.sendTimeout {
            timer.invalidate()
            self.sendTimeout = nil;
        }
        if let last = self.tableData.last {
            if let lastwaiting = last["waiting"] {
                if lastwaiting as! Bool == true {
                    self.tableData.removeLast()
                }
            }
        }
    }
    
    func showWaiting() {
        sendTimeoutCount = 0
        let table = ["●○○○○","○●○○○","○○●○○","○○○●○","○○○○●","○○○●○","○○●○○","○●○○○","●○○○○"]
        sendTimeout = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true, block: { (timer) in
            DispatchQueue.main.async {
                let str = table[self.sendTimeoutCount%table.count]
                self.sendTimeoutCount = self.sendTimeoutCount + 1
                if (self.sendTimeoutCount > 1) {
                    _ = self.tableData.popLast()
                }
                self.tableData.append(["name": self.agent_name as AnyObject, "type": 1 as AnyObject,  "waiting":true as AnyObject, "image": "conversation.png" as AnyObject, "message": str as AnyObject])
                self.refreshTableView()
            }
        })
    }

    open func getConversation(pre: Locale) -> HLPConversation{
        return ConversationEx()
    }
    
    var sendTimeout:Timer? = nil
    var sendTimeoutCount = 0
    
    open func sendMessage(_ msg: String, notimeout: Bool = false){
        if notimeout == false {
            self.showWaiting()
        }
        if !msg.isEmpty{
            newmessage(msg)

            //NavSound.sharedInstance().vibrate(nil)
            //NavSound.sharedInstance().playVoiceRecoEnd()
        }

        let pre = Locale(identifier: Locale.preferredLanguages[0])

        let conversation = self.getConversation(pre:pre)//ConversationEx()
        if var context = self.conv_context {
            self.conv_context_local.getContext().forEach({ (arg) in
                let (key, value) = arg
                context.additionalProperties[key] = value
            })

            conversation.message(msg, server: self.conv_server!, api_key: self.conv_api_key!, client_id: self.conv_client_id, context: context) { [weak self] (response, error) in
                if let weakself = self {
                    if let error = error {
                        weakself.removeWaiting()
                        weakself.failureCustom(error)
                        return
                    }
                    guard let message = response?.result else {
                        return
                    }
                    let conversationID = response?.result?.context.conversationID
                    if conversationID != weakself.conversation_id {
                        weakself.conversation_id = conversationID
                        NSLog("conversationid changed: " + weakself.conversation_id!)
                    }
                    weakself.removeWaiting()
                    weakself.newresponse(message)
                }
            }
        } else {
            let initial_context = Context(conversationID: nil, system: nil, additionalProperties: self.conv_context_local.getContext())
            conversation.message(msg, server: self.conv_server!, api_key: self.conv_api_key!, client_id: self.conv_client_id, context: initial_context) { [weak self] (response, error) in
                if let weakself = self {
                    if let error = error {
                        weakself.removeWaiting()
                        weakself.failureCustom(error)
                    }
                    guard let message = response?.result else {
                        return
                    }
                    weakself.removeWaiting()
                    weakself.newresponse(message)
                }
            }
        }
    }
    internal func endspeak(_ rsp:String?){
        if self.inflight != nil{
            self.inflight?.invalidate()
            self.inflight = nil
        }
    }
    func suspendDialog() {
        let stt = self.getStt()
        stt.endRecognize()
        stt.disconnect()
    }
    func dummy(_ msg:String){
        //nop
    }

    func headupDialog(_ speech: String?) {
        let stt:STTHelper = self.getStt()
        stt.endRecognize()
        stt.prepare()
        if speech != nil {
            stt.listen([([".*"], {[weak self] (str, dur) in
                if let weakself = self {
                    weakself.dummy(str)
                }
            })], selfvoice: speech!,
                 speakendactions:[({[weak self] str in
                if let weakself = self {
                    weakself.endspeak(nil)
                }
            })],
                 avrdelegate: nil,
                 failure:{[weak self] (e) in
                if let weakself = self {
                    weakself.failureCustom(e)
            }},
                 timeout:{[weak self] in
                if let weakself = self {
                    weakself.timeoutCustom()
            }})
        }else{
            if self._lastspeech != nil{
                self.newresponse(nil)
            }
        }
    }
    var _lastspeech:String? = nil
    func startDialog(_ response:String) {
        let stt:STTHelper = self.getStt()
        stt.endRecognize()
        stt.delegate = self.dialogViewHelper
        self._lastspeech = response

        stt.listen([([".*"], {[weak self] (str, dur) in
            if let weakself = self {
                weakself.sendMessage(str)
            }
        })], selfvoice: response,speakendactions:[({[weak self] str in
            if let weakself = self {
                if let lastdata = weakself.tableData.last{
                    if 3 == lastdata["type"] as! Int{
                        if weakself.tableView != nil{
                            let nos = weakself.tableView!.numberOfSections
                            let nor = weakself.tableView!.numberOfRows(inSection: nos-1)
                            if nor > 0{
                                let lastPath:IndexPath = IndexPath(row:nor-1, section:nos-1)
                                if let tablecell:CustomLeftTableViewCellSpeaking = weakself.tableView!.cellForRow(at: lastPath) as? CustomLeftTableViewCellSpeaking{
                                    tablecell.showAllText()
                                }
                            }
                        }
                        let nm = lastdata["name"]
                        let img = lastdata["image"]
                        let msg = lastdata["message"]
                        weakself.tableData.removeLast()
                        weakself.tableData.append(["name": nm!, "type": 1, "image": img!, "message": msg!])
                    }
                }
                weakself.endspeak(str)
            }
        })], avrdelegate: nil, failure:{[weak self] (e) in
            if let weakself = self {
                weakself.failureCustom(e)
            }
        }, timeout:{[weak self] in
            if let weakself = self {
                weakself.timeoutCustom()
            }
        })
    }
    
    func endDialog(_ response:String){
        let stt:STTHelper = self.getStt()
        stt.endRecognize()
        stt.delegate = self.dialogViewHelper
        self._lastspeech = response
    }
    
    func failDialog() {
        let stt:STTHelper = self.getStt()
        stt.endRecognize()
        stt.paused = true
        stt.delegate?.showText(NSLocalizedString("PAUSING", tableName: nil, bundle: Bundle.module, value: "", comment:"Pausing"));
        stt.delegate?.inactive()
        stt.delegate = self.dialogViewHelper
    }
    
    func failureCustom(_ error: Error){
        print(error, to:&standardError)
        let str = error.localizedDescription
        self.removeWaiting()
        self.tableData.append(["name": NSLocalizedString("Error", tableName: nil, bundle: Bundle.module, value: "", comment:"") as AnyObject, "type": 1 as AnyObject,  "image": "conversation.png" as AnyObject, "message": str as AnyObject])
        self.refreshTableView()
        DispatchQueue.main.async(execute: { [weak self] in
            if let weakself = self {
                weakself.failDialog()
                weakself.tts?.speak(str) {
                }
            }
            })
        DispatchQueue.main.async(execute: { [weak self] in
            if let weakself = self {
                weakself.cancellable = true
                weakself.updateView()
            }
        })
    }
    
    var timeoutCount = 0
    
    func timeoutCustom(){
        if timeoutCount >= 0 { // temporary fix
            let str = NSLocalizedString("WAIT_ACTION", tableName: nil, bundle: Bundle.module, value: "", comment:"")
            self.tableData.append(["name": self.agent_name as AnyObject, "type": 1 as AnyObject,  "image": "conversation.png" as AnyObject, "message": str as AnyObject])
            self.refreshTableView()
            self.failDialog()
            self.tts?.speak(str) {
            }
            return
        }
        
        self.sendMessage("", notimeout: true)
        timeoutCount = timeoutCount + 1
    }
    
    func justSpeech(_ response: String){
        let stt:STTHelper = self.getStt()
        stt.endRecognize()
        stt.delegate = self.dialogViewHelper
        
        stt.listen([([".*"], {[weak self] (_,_) in
            if let weakself = self {
                weakself.sendMessage("")
            }
        })], selfvoice: response,speakendactions:[({[weak self] str in
            if let weakself = self {
                weakself.endspeak(str)
            }
        })], avrdelegate:nil, failure:{[weak self] (error) in
            if let weakself = self {
                weakself.failureCustom(error)
            }
        }, timeout:{[weak self] in
            if let weakself = self {
                weakself.timeoutCustom()
            }
        })
    }
}

