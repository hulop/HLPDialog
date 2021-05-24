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

public protocol HLPConversation {
    func errorResponseDecoder(data: Data, response: HTTPURLResponse) -> RestError

    func message(
        _ text: String?,
        server: String,
        api_key: String,
        client_id: String?,
        context: Context?,
        completionHandler: @escaping (RestResponse<MessageResponse>?, Error?) -> Void)
}

@objcMembers
open class ConversationEx: HLPConversation {

    fileprivate let domain = "hulop.navcog.ConversationV1"
    static var running = false

    private let session = URLSession(configuration: .default)

    public init() {
    }

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

    public func message(
        _ text: String? = nil,
        server: String,
        api_key: String,
        client_id: String? = nil,
        context: Context? = nil,
        completionHandler: @escaping (RestResponse<MessageResponse>?, Error?) -> Void)
    {
        if ConversationEx.running {
            return
        }

        // construct body
        let messageRequest = MessageRequest(
            input: InputData(text: text ?? ""),
            context: context)
        guard let body = try? JSONEncoder().encodeIfPresent(messageRequest) else {
            let failureReason = "context could not be serialized to JSON."
            let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
            let error = NSError(domain: domain, code: 0, userInfo: userInfo)
            completionHandler(nil, error)
            return
        }

        // construct header parameters
        var headerParameters = [String: String]()
        headerParameters["Accept"] = "application/json"
        headerParameters["Content-Type"] = "application/json"
        //headerParameters["User-Agent"] = "NavCogDialog"

        // construct query parameters
        var queryParameters = [URLQueryItem]()
        queryParameters.append(URLQueryItem(name: "lang", value: (Locale.current as NSLocale).languageCode))
        if text != nil {
            queryParameters.append(URLQueryItem(name: "text", value: text))
        }
        if client_id != nil {
            queryParameters.append(URLQueryItem(name: "id", value: client_id))
        }

        // construct REST request
        let authMethod = APIKeyAuthentication(name: "api_key", key: api_key, location: .query)
        let https = DialogManager.sharedManager().useHttps ? "https" : "http"
        let url = https + "://" + server + "/service"
        let request = RestRequest(
            session: session,
            authMethod: authMethod,
            errorResponseDecoder: errorResponseDecoder,
            method: "POST",
            url: url,
            headerParameters: headerParameters,
            queryItems: queryParameters,
            messageBody: body
        )

        // execute REST request
        ConversationEx.running = true
        request.responseObject { (response: RestResponse<MessageResponse>?, error: RestError?) in
            ConversationEx.running = false
            if let error = error {
                print("RestError: ", error.localizedDescription)
                switch error {
                case .noResponse:
                    let domain = "swift.conversationex"
                    let code = -1
                    let message = NSLocalizedString("checkNetworkConnection", tableName: nil, bundle: Bundle.module, value: "", comment:"")
                    let userInfo = [NSLocalizedDescriptionKey: message]
                    completionHandler(response, NSError(domain: domain, code: code, userInfo: userInfo))
                default:
                    let domain = "swift.conversationex"
                    let code = -1
                    let message = NSLocalizedString("serverConnectionError", tableName: nil, bundle: Bundle.module, value: "", comment:"")
                    let userInfo = [NSLocalizedDescriptionKey: message]
                    completionHandler(response, NSError(domain: domain, code: code, userInfo: userInfo))
                }
                return
            }
            completionHandler(response, nil)
        }
    }
}
