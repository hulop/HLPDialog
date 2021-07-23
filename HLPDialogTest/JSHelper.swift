/*******************************************************************************
 * Copyright (c) 2021  Carnegie Mellon University
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
import JavaScriptCore
import UIKit


// main class
class JSHelper {
    let ctx: JSContext
    let script: String

    init(withScript jsFile: URL) {
        self.ctx = JSContext()
        NSLog("loading \(jsFile)")

        do {
            script = try String(contentsOf: jsFile, encoding: .utf8)

            // JavaScript syntax check
            ctx.exceptionHandler = { context, value in
                let lineNumber:Int = Int(value!.objectForKeyedSubscript("line")!.toInt32())
                guard lineNumber > 0 else { return }
                let moreInfo = "\(jsFile.path)#L\(lineNumber)"
                NSLog("JS ERROR: \(value!) \(moreInfo)")
                let start = max(lineNumber-2, 0)
                for i in (start)..<lineNumber {
                    NSLog("L%-4d %s", i+1, String(self.script.split(separator: "\n", omittingEmptySubsequences:false)[i]))
                }
                exit(0)
            }
            // load script
            ctx.evaluateScript(script)
        } catch {
            script = ""
            NSLog("Cannot load the script \(jsFile.path)")
            exit(0)
        }
    }

    func call(_ funcName:String, withArguments args: [Any]) -> JSValue! {
        if let funk = ctx.objectForKeyedSubscript(funcName) {
            guard !funk.isUndefined else { NSLog("\(funcName) is not defined"); return funk }
            guard !funk.isNull else { NSLog("\(funcName) is null"); return funk }
            return funk.call(withArguments: args)
        }
        return nil
    }

}
