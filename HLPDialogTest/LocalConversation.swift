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
import RestKit
import AssistantV1
import HLPDialog

class LocalConversation: HLPConversation {

    fileprivate let domain = "cabot.LocalConversation"

    public func errorResponseDecoder(data: Data, response: HTTPURLResponse) -> RestError {

        let statusCode = response.statusCode
        var errorMessage: String?
        var metadata = [String: Any]()

        do {
            let json = try JSONDecoder().decode([String: JSON].self, from: data)
            metadata = [:]
            if case let .some(.string(message)) = json["error"] {
                errorMessage = message
            }
            // If metadata is empty, it should show up as nil in the RestError
            return RestError.http(statusCode: statusCode, message: errorMessage, metadata: !metadata.isEmpty ? metadata : nil)
        } catch {
            return RestError.http(statusCode: statusCode, message: nil, metadata: nil)
        }
    }

    public func _getResponse(_ request: Any) -> [String:Any] {
        let speak = "Test, test"
        return [
            "output": [
                "log_messages":[],
                "text": [speak]
            ],
            "intents":[],
            "entities":[],
            "context":[
                "navi": false,
                "dest_info": nil,
                "find_info": nil,
                "system":[
                    "dialog_request_counter":0
                ]
            ]
        ]
    }

    public func message(
        _ text: String? = nil,
        server: String,
        api_key: String,
        client_id: String? = nil,
        context: Context? = nil,
        completionHandler: @escaping (RestResponse<MessageResponse>?, Error?) -> Void)
    {
        // construct body
        let messageRequest = MessageRequest(
            input: InputData(text: text ?? ""),
            context: context)

        guard let request = try? JSONSerialization.jsonObject(with: JSONEncoder().encodeIfPresent(messageRequest)) else {
            let failureReason = "context could not be serialized to JSON."
            let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
            let error = NSError(domain: domain, code: 0, userInfo: userInfo)
            completionHandler(nil, error)
            return
        }

        let json = try! JSONSerialization.data(withJSONObject: self._getResponse(request), options: [])
        let resmsg:MessageResponse = try! JSONDecoder().decode(MessageResponse.self, from:json)
        var res:RestResponse<MessageResponse> = RestResponse<MessageResponse>(statusCode: 200)
        res.result = resmsg
        DispatchQueue.global().async{
            completionHandler(res, nil)
        }
    }
}
