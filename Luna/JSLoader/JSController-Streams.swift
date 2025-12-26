//
//  JSLoader-Streams.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import JavaScriptCore

extension JSController {
    func fetchStreamUrlJS(episodeUrl: String, softsub: Bool = false, module: Service, completion: @escaping ((streams: [String]?, subtitles: [String]?,sources: [[String:Any]]? )) -> Void) {
        if let exception = context.exception {
            Logger.shared.log("JavaScript exception: \(exception)", type: "Error")
            completion((nil, nil,nil))
            return
        }
        
        guard let extractStreamUrlFunction = context.objectForKeyedSubscript("extractStreamUrl") else {
            Logger.shared.log("No JavaScript function extractStreamUrl found", type: "Error")
            completion((nil, nil,nil))
            return
        }
        
        let promiseValue = extractStreamUrlFunction.call(withArguments: [episodeUrl])
        guard let promise = promiseValue else {
            Logger.shared.log("extractStreamUrl did not return a Promise", type: "Error")
            completion((nil, nil,nil))
            return
        }
        
        let thenBlock: @convention(block) (JSValue) -> Void = { [weak self] result in
            guard self != nil else { return }
            
            if result.isNull || result.isUndefined {
                Logger.shared.log("Received null or undefined result from JavaScript", type: "Error")
                DispatchQueue.main.async { completion((nil, nil, nil)) }
                return
            }
            
            if let resultString = result.toString(), resultString == "[object Promise]" {
                Logger.shared.log("Received Promise object instead of resolved value, waiting for proper resolution", type: "Stream")
                return
            }
            
            guard let jsonString = result.toString() else {
                Logger.shared.log("Failed to convert JSValue to string", type: "Error")
                DispatchQueue.main.async { completion((nil, nil, nil)) }
                return
            }
            
            guard let data = jsonString.data(using: .utf8) else {
                Logger.shared.log("Failed to convert string to data", type: "Error")
                DispatchQueue.main.async { completion((nil, nil, nil)) }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    var streamUrls: [String]? = nil
                    var subtitleUrls: [String]? = nil
                    var streamUrlsAndHeaders : [[String:Any]]? = nil
                    
                    if let streamSources = json["streams"] as? [[String:Any]] {
                        streamUrlsAndHeaders = streamSources
                        Logger.shared.log("Found \(streamSources.count) streams and headers", type: "Stream")
                    } else if let streamSource = json["stream"] as? [String:Any] {
                        streamUrlsAndHeaders = [streamSource]
                        Logger.shared.log("Found single stream with headers", type: "Stream")
                    } else if let streamsArray = json["streams"] as? [String] {
                        streamUrls = streamsArray
                        Logger.shared.log("Found \(streamsArray.count) streams", type: "Stream")
                    } else if let streamUrl = json["stream"] as? String {
                        streamUrls = [streamUrl]
                        Logger.shared.log("Found single stream", type: "Stream")
                    }
                    
                    if let subsArray = json["subtitles"] as? [String] {
                        subtitleUrls = subsArray
                        Logger.shared.log("Found \(subsArray.count) subtitle tracks", type: "Stream")
                    } else if let subtitleUrl = json["subtitles"] as? String {
                        subtitleUrls = [subtitleUrl]
                        Logger.shared.log("Found single subtitle track", type: "Stream")
                    }
                    
                    Logger.shared.log("Starting stream with \(streamUrls?.count ?? 0) sources and \(subtitleUrls?.count ?? 0) subtitles", type: "Stream")
                    DispatchQueue.main.async {
                        completion((streamUrls, subtitleUrls, streamUrlsAndHeaders))
                    }
                    return
                }
                
                if let streamsArray = try JSONSerialization.jsonObject(with: data, options: []) as? [String] {
                    Logger.shared.log("Starting multi-stream with \(streamsArray.count) sources", type: "Stream")
                    DispatchQueue.main.async { completion((streamsArray, nil, nil)) }
                    return
                }
            } catch {
                Logger.shared.log("JSON parsing error: \(error.localizedDescription)", type: "Error")
            }
            
            Logger.shared.log("Starting stream from: \(jsonString)", type: "Stream")
            DispatchQueue.main.async {
                completion(([jsonString], nil, nil))
            }
        }
        
        let catchBlock: @convention(block) (JSValue) -> Void = { error in
            let errorMessage = error.toString() ?? "Unknown JavaScript error"
            Logger.shared.log("Promise rejected: \(errorMessage)", type: "Error")
            DispatchQueue.main.async {
                completion((nil, nil, nil))
            }
        }
        
        let thenFunction = JSValue(object: thenBlock, in: context)
        let catchFunction = JSValue(object: catchBlock, in: context)
        
        guard let thenFunction = thenFunction, let catchFunction = catchFunction else {
            Logger.shared.log("Failed to create JSValue objects for Promise handling", type: "Error")
            completion((nil, nil, nil))
            return
        }
        
        promise.invokeMethod("then", withArguments: [thenFunction])
        promise.invokeMethod("catch", withArguments: [catchFunction])
    }
}
