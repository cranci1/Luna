//
//  KanzenModuleRunner.swift
//  Kanzen
//
//  Created by Dawud Osman on 12/05/2025.
//

import Foundation
import JavaScriptCore

class KanzenModuleRunner
{
    private let contextQueue: DispatchQueue = DispatchQueue(label: "com.Kanzen.Module.Runner.Context")
    private var jsContext: JSContext?
    private var lastJSException: String?
    
    func getChapterImages(params:Any, completion: @escaping (JSValue?,Error?) -> Void)
    {
        guard let context = jsContext else {
            completion(nil, NSError(domain: "JSContext", code: 1, userInfo: [NSLocalizedDescriptionKey: "JS function not found"]))
            return
        
        }
        guard let chaptersFunc = context.objectForKeyedSubscript("getChapterImages") else {
            completion(nil, NSError(domain: "JSContext", code: 1, userInfo: [NSLocalizedDescriptionKey: "JS function not found"]))
            return
        }
        guard let promise = chaptersFunc.call(withArguments: [params]) else {
            completion(nil, NSError(domain: "JSContext", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to call JS async function"]))
            return
        }
        // Prepare resolve and reject blocks
        let resolveBlock: @convention(block) (JSValue) -> Void = { result in

            completion(result, nil)
        }
        let rejectBlock: @convention(block) (JSValue) -> Void = { error in

            let err = NSError(domain: "JSContext", code: 3, userInfo: [NSLocalizedDescriptionKey: error.toString() ?? "-"])
            completion(nil, err)
        }
        let resolveCallback = JSValue(object: resolveBlock, in: context)
        let rejectCallback = JSValue(object: rejectBlock, in: context)

        // Attach callbacks to the Promise
        promise.invokeMethod("then", withArguments: [resolveCallback as Any])
        promise.invokeMethod("catch", withArguments: [rejectCallback as Any])
    }
    
    func getChapters(params:Any, completion: @escaping (JSValue?,Error?) -> Void)
    {
        guard let context = jsContext else {
            completion(nil, NSError(domain: "JSContext", code: 1, userInfo: [NSLocalizedDescriptionKey: "JS function not found"]))
            return
        
        }
        guard let chaptersFunc = context.objectForKeyedSubscript("getChapters") else {
            completion(nil, NSError(domain: "JSContext", code: 1, userInfo: [NSLocalizedDescriptionKey: "JS function not found"]))
            return
        }
        guard let promise = chaptersFunc.call(withArguments: [params]) else {
            completion(nil, NSError(domain: "JSContext", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to call JS async function"]))
            return
        }
        // Prepare resolve and reject blocks
        let resolveBlock: @convention(block) (JSValue) -> Void = { result in

            completion(result, nil)
        }
        let rejectBlock: @convention(block) (JSValue) -> Void = { error in

            let err = NSError(domain: "JSContext", code: 3, userInfo: [NSLocalizedDescriptionKey: error.toString() ?? "-"])
            completion(nil, err)
        }
        let resolveCallback = JSValue(object: resolveBlock, in: context)
        let rejectCallback = JSValue(object: rejectBlock, in: context)

        // Attach callbacks to the Promise
        promise.invokeMethod("then", withArguments: [resolveCallback as Any])
        promise.invokeMethod("catch", withArguments: [rejectCallback as Any])
    }

    func getContentData(params:Any, completion: @escaping (JSValue?,Error?) -> Void)
    {

        guard let context = jsContext else {
            completion(nil, NSError(domain: "JSContext", code: 1, userInfo: [NSLocalizedDescriptionKey: "JS function not found"]))
            return
        }
        
        guard let contentDataFunc = context.objectForKeyedSubscript("getContentData") else {
            completion(nil, NSError(domain: "JSContext", code: 1, userInfo: [NSLocalizedDescriptionKey: "JS function not found"]))
            return
        }
        guard let promise = contentDataFunc.call(withArguments: [params]) else {
            completion(nil, NSError(domain: "JSContext", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to call JS async function"]))
            return
        }
        // Prepare resolve and reject blocks
        let resolveBlock: @convention(block) (JSValue) -> Void = { result in

            completion(result, nil)
        }
        let rejectBlock: @convention(block) (JSValue) -> Void = { error in

            let err = NSError(domain: "JSContext", code: 3, userInfo: [NSLocalizedDescriptionKey: error.toString() ?? "-"])
            completion(nil, err)
        }
        let resolveCallback = JSValue(object: resolveBlock, in: context)
        let rejectCallback = JSValue(object: rejectBlock, in: context)

        // Attach callbacks to the Promise
        promise.invokeMethod("then", withArguments: [resolveCallback as Any])
        promise.invokeMethod("catch", withArguments: [rejectCallback as Any])
    }
    
    func searchContent(input:String, page:Int = 0,completion: @escaping(JSValue?,Error?) -> Void)
    {

        guard let context = jsContext else {
            completion(nil, NSError(domain: "JSContext", code: 1, userInfo: [NSLocalizedDescriptionKey: "JS function not found"]))
            return
        }
     

        guard let searchFunc = context.objectForKeyedSubscript("searchContent") else {
            completion(nil, NSError(domain: "JSContext", code: 1, userInfo: [NSLocalizedDescriptionKey: "JS function not found"]))
            return
        }

        guard let promise = searchFunc.call(withArguments: [input,page]) else {
            completion(nil, NSError(domain: "JSContext", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to call JS async function"]))
            return
        }
        
        // Prepare resolve and reject blocks
        let resolveBlock: @convention(block) (JSValue) -> Void = { result in

            completion(result, nil)
        }
        let rejectBlock: @convention(block) (JSValue) -> Void = { error in

            let err = NSError(domain: "JSContext", code: 3, userInfo: [NSLocalizedDescriptionKey: error.toString() ?? "-"])
            completion(nil, err)
        }
        let resolveCallback = JSValue(object: resolveBlock, in: context)
        let rejectCallback = JSValue(object: rejectBlock, in: context)

        // Attach callbacks to the Promise
        promise.invokeMethod("then", withArguments: [resolveCallback as Any])
        promise.invokeMethod("catch", withArguments: [rejectCallback as Any])
    }
    
    func setUpEnvironMent()
    {
        jsContext = JSContext()
        jsContext?.exceptionHandler = { _, exception in
            print("JS Error: \(exception?.toString() ?? "unknown error")")
            Logger.shared.log( "JS Error: \(exception?.toString() ?? "unknown error")",type: "Error")
            self.lastJSException = "JS Error: \(exception?.toString() ?? "unknown error")"
        }
        jsContext?.setUpJSEnvirontment()
    }
    
    func loadScript(_ script: String) throws
    {
        
            lastJSException = nil
            setUpEnvironMent()
            jsContext?.evaluateScript(script)

        
        if let exception = self.lastJSException
        {
            
            let errorMessage = exception
            throw ScriptExecutionError.scriptLoadError(errorMessage)
        }
    }
}
