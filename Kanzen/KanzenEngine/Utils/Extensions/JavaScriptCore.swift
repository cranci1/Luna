//
//  JavaScriptCore.swift
//  Kanzen
//
//  Created by Dawud Osman on 13/05/2025.
//

import JavaScriptCore
import Foundation

extension JSContext
{
    func setupTimeOut()
    {
        // 2. Define `setTimeout` in Swift
        let setTimeout: @convention(block) (JSValue, Double) -> Void = { callback, delay in
            let delayTime = DispatchTime.now() + delay / 1000.0  // Convert ms to seconds
            DispatchQueue.main.asyncAfter(deadline: delayTime) {
                callback.call(withArguments: [])
            }
        }
        // 3. Inject `setTimeout` into JSContext
        self.setObject(setTimeout, forKeyedSubscript: "setTimeout" as (NSCopying & NSObjectProtocol))
    }
    
    func setupBundle()
    {
        guard let jsPath = Bundle.main.path(forResource: "bundle", ofType: "js")
        else{
            Logger.shared.log("bundle not found",type: "Error")
            return
        }
        do {
            let jsCode = try String(contentsOfFile: jsPath, encoding: .utf8)
            self.evaluateScript(jsCode)
            Logger.shared.log("bundle loaded successfully")
        } catch {
            Logger.shared.log("Error loading bundle.js: \(error)")
        }
        
    }
    
    func setUpConsole()
    {
        let consoleObject = JSValue(newObjectIn: self)
        let consoleLogFunction: @convention(block) (String) -> Void = {
            message in
            Logger.shared.log(message,type: "Debug")
        }
        let consolePrintFunction: @convention(block) (JSValue) -> Void = {
            message in
            print(message)
        }
        
        consoleObject?.setObject(consoleLogFunction, forKeyedSubscript: "log" as NSString)
        consoleObject?.setObject(consolePrintFunction, forKeyedSubscript: "print" as NSString)
        self.setObject(consoleObject, forKeyedSubscript: "console" as NSString)
    }
    
    func setUpFetch()
    {
        let fetch: @convention(block) (JSValue,JSValue) -> JSValue = {
            jsUrl, jsOptions in
            guard let urlStr = jsUrl.toString(), let url = URL(string: urlStr) else
            {
                return JSValue(newErrorFromMessage: "Invalid URL", in: self)
            }
            
            guard let promiseConstructor = self.objectForKeyedSubscript("Promise") else
            {
                fatalError("Promise constructor not found in JSContext")
            }
            
            let executor: @convention(block) (@escaping (JSValue) -> Void, @escaping (JSValue) -> Void) -> Void = { resolve, reject in
                var request  = URLRequest(url: url)
                request.httpMethod = "GET"
                if let options = jsOptions.toDictionary() as? [String: Any]
                {
                    if let method = options["method"] as? String
                    {
                        request.httpMethod = method.uppercased()
                    }
                    if let headers = options["headers"] as? [String: String]
                    {
                        for (key,value) in headers
                        {
                            request.addValue(value, forHTTPHeaderField: key)
                        }
                    }
                    if let body = options["body"] as? String
                    {
                        let bodyData = body.data(using: .utf8)
                        request.httpBody = bodyData
                    }
                }
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    
                    if let error = error
                    {
                        return reject(JSValue(newErrorFromMessage: error.localizedDescription, in: self))
                    }
                    guard let  httpResponse = response as? HTTPURLResponse
                    else
                    {
                        reject(JSValue(newErrorFromMessage: "No Response", in: self ))
                        return
                    }
                    let textFunc: @convention(block) () -> String = {
                        if let data = data
                        {
                            return String(data: data, encoding: .utf8) ?? ""
                        }
                        return ""
                    }
                    let jsonFunc: @convention(block) () -> JSValue = {
                        if let data = data {
                            do{
                                let json = try JSONSerialization.jsonObject(with: data, options: [])
                                return JSValue(object: json, in: self)
                            }
                            catch
                            {
                                Logger.shared.log("JSON serialization failed",type:"Error")
                            }
                        }
                        return JSValue(newErrorFromMessage: "No Data", in: self)
                        
                    }
                    guard let textJs = JSValue(object: textFunc, in: self),
                          let jsonJs = JSValue(object: jsonFunc, in: self)
                    else
                    {
                        return reject(JSValue(newErrorFromMessage: "Failed to create JSValue", in: self))
                    }
                    let responseObject: [String: Any] = [
                        "status": httpResponse.statusCode,
                        "headers": httpResponse.allHeaderFields,
                        "text": textJs,
                        "json": jsonJs,
                        "data": data?.base64EncodedString() ?? ""
                    ]
                    
                    resolve(JSValue(object: responseObject, in: self))
                    
                }
                task.resume()
                
            }
            
            let promise = JSValue(newPromiseIn: self, fromExecutor: { resolve, reject in
                executor(
                    { value in resolve?.call(withArguments: [value]) },
                    { error in reject?.call(withArguments: [error]) }
                )
            })
            
            return promise ?? JSValue(newErrorFromMessage: "Promise not supported", in: self)
            
        }
        
        self.setObject(fetch, forKeyedSubscript: "fetch" as NSString)
    }
    
    func setUpJSEnvirontment()
    {
        setUpFetch()
        setUpConsole()
        setupBundle()
        setupTimeOut()
    }
}
