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

@objcMembers
public class DialogManager: NSObject {

    static let REQUEST_DIALOG_ACTION:Notification.Name = Notification.Name(rawValue:"REQUEST_DIALOG_ACTION")
    static let REQUEST_DIALOG_PAUSE:Notification.Name = Notification.Name(rawValue:"REQUEST_DIALOG_PAUSE")
    static let REQUEST_DIALOG_END:Notification.Name = Notification.Name(rawValue:"REQUEST_DIALOG_END")
    
    public static let DIALOG_AVAILABILITY_CHANGED_NOTIFICATION:Notification.Name = Notification.Name(rawValue:"DIALOG_AVAILABILITY_CHANGED_NOTIFICATION")
    
    var latitude:Double?, longitude:Double?, floor:Int?, building:String?
    public internal(set) var isActive:Bool = false
    public var config: [String: Any]? = nil {
        didSet {
            isAvailable = false
            // check serverconfig
            if let conf = config {
                let server = conf["conv_server"]
                if let _server = server as? String {
                    if !_server.isEmpty {
                        let key = conf["conv_api_key"]
                        if let _key = key as? String {
                            if !_key.isEmpty {
                                isAvailable = true
                            }
                        }
                    }
                }
            }
        }
    }
    public var useHttps:Bool = true
    public var userMode:String = "user_general"
    public internal(set) var isAvailable:Bool = false {
        didSet {
            NotificationCenter.default.post(name: DialogManager.DIALOG_AVAILABILITY_CHANGED_NOTIFICATION, object:self, userInfo:["available":isAvailable])
        }
    }
    static var instance:DialogManager?
    @discardableResult public static func sharedManager()->DialogManager {
        if instance == nil {
            instance = DialogManager()
        }
        return instance!
    }
    
    override init() {
        super.init()
    }
    
    public func changeLocation(lat: Double, lng: Double, floor: Double) {
        self.latitude = nil
        self.longitude = nil
        self.floor = nil
        if (!lat.isNaN && !lng.isNaN) {
            self.latitude = lat
            self.longitude = lng
        }
        if (!floor.isNaN) {
            self.floor = Int(round(floor))
        }
    }

    public func changeBuilding (_ building:String?) {
        self.building = building
    }
    
    func setLocationContext(_ context:inout [String: JSON]) {
        if let latitude = latitude {
            context["latitude"] = JSON.double(latitude)
            if let longitude = longitude {
                context["longitude"] = JSON.double(longitude)
            }
        }
        if let floor = floor {
            context["floor"] = JSON.int(floor)
        }
        if let building = building {
            context["building"] =  JSON.string(building)
        } else {
            context["building"] =  JSON.string("")
        }
        context["user_mode"] = JSON.string(userMode)
    }
    
    public func action() {
        let nc = NotificationCenter.default
        nc.post(name: DialogManager.REQUEST_DIALOG_ACTION, object: nil)
    }
    
    public func pause() {
        let nc = NotificationCenter.default
        nc.post(name: DialogManager.REQUEST_DIALOG_PAUSE, object: nil)
    }
    
    public func end() {
        let nc = NotificationCenter.default
        nc.post(name: DialogManager.REQUEST_DIALOG_END, object: nil)
    }
}
