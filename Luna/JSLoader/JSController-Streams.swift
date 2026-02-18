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
        
        func parsePayloadObject(_ json: [String: Any]) -> (streams: [String]?, subtitles: [String]?, sources: [[String: Any]]?) {
            var streamUrls: [String]? = nil
            var subtitleUrls: [String]? = nil
            var streamUrlsAndHeaders: [[String: Any]]? = nil

            // Streams/sources can come in many shapes depending on the module.
            // Prefer structured sources when present.
            if let streamSources = json["streams"] as? [[String: Any]] {
                streamUrlsAndHeaders = streamSources
                Logger.shared.log("Found \(streamSources.count) streams and headers", type: "Stream")
            } else if let streamSources = json["sources"] as? [[String: Any]] {
                streamUrlsAndHeaders = streamSources
                Logger.shared.log("Found \(streamSources.count) sources", type: "Stream")
            } else if let streamSource = json["stream"] as? [String: Any] {
                streamUrlsAndHeaders = [streamSource]
                Logger.shared.log("Found single stream with headers", type: "Stream")
            } else if let streamsArray = json["streams"] as? [String] {
                streamUrls = streamsArray
                Logger.shared.log("Found \(streamsArray.count) streams", type: "Stream")
            } else if let streamsArray = json["sources"] as? [String] {
                streamUrls = streamsArray
                Logger.shared.log("Found \(streamsArray.count) sources (string array)", type: "Stream")
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
            } else if let subsArray = json["subtitle"] as? [String] {
                subtitleUrls = subsArray
                Logger.shared.log("Found \(subsArray.count) subtitle tracks (singular key)", type: "Stream")
            } else if let subtitleUrl = json["subtitle"] as? String {
                subtitleUrls = [subtitleUrl]
                Logger.shared.log("Found single subtitle track (singular key)", type: "Stream")
            }

            // Some modules nest the payload under result.
            if (streamUrls == nil && streamUrlsAndHeaders == nil), let result = json["result"] as? [String: Any] {
                let nested = parsePayloadObject(result)
                streamUrls = nested.streams
                subtitleUrls = subtitleUrls ?? nested.subtitles
                streamUrlsAndHeaders = nested.sources
            }

            return (streamUrls, subtitleUrls, streamUrlsAndHeaders)
        }

        var thenFunction: JSValue? = nil
        var catchFunction: JSValue? = nil

        let thenBlock: @convention(block) (JSValue) -> Void = { [weak self] result in
            guard let self else { return }
            
            if result.isNull || result.isUndefined {
                Logger.shared.log("Received null or undefined result from JavaScript", type: "Error")
                DispatchQueue.main.async { completion((nil, nil, nil)) }
                return
            }
            
            if let resultString = result.toString(), resultString == "[object Promise]" {
                // Some modules mistakenly resolve to a Promise-of-a-Promise.
                // Chain the returned Promise so we still complete and don't hang the UI.
                Logger.shared.log("Received nested Promise; chaining...", type: "Stream")
                guard let thenFn = thenFunction, let catchFn = catchFunction else {
                    Logger.shared.log("Failed to chain nested Promise (missing handlers)", type: "Error")
                    DispatchQueue.main.async { completion((nil, nil, nil)) }
                    return
                }
                result.invokeMethod("then", withArguments: [thenFn])
                result.invokeMethod("catch", withArguments: [catchFn])
                return
            }

            // Prefer native object conversion (handles JS objects/arrays) over stringification.
            if let object = result.toObject() {
                if let json = object as? [String: Any] {
                    let parsed = parsePayloadObject(json)
                    Logger.shared.log("Starting stream with \(parsed.streams?.count ?? 0) sources and \(parsed.subtitles?.count ?? 0) subtitles", type: "Stream")
                    DispatchQueue.main.async {
                        completion((parsed.streams, parsed.subtitles, parsed.sources))
                    }
                    return
                }
                if let array = object as? [Any] {
                    let strings = array.compactMap { $0 as? String }
                    if !strings.isEmpty {
                        Logger.shared.log("Starting multi-stream with \(strings.count) sources", type: "Stream")
                        DispatchQueue.main.async { completion((strings, nil, nil)) }
                        return
                    }
                }
            }

            // Fallback: try to parse as JSON text if the module returned a JSON string.
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
                    let parsed = parsePayloadObject(json)
                    Logger.shared.log("Starting stream with \(parsed.streams?.count ?? 0) sources and \(parsed.subtitles?.count ?? 0) subtitles", type: "Stream")
                    DispatchQueue.main.async {
                        completion((parsed.streams, parsed.subtitles, parsed.sources))
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
            DispatchQueue.main.async { completion(([jsonString], nil, nil)) }
        }
        
        let catchBlock: @convention(block) (JSValue) -> Void = { error in
            let errorMessage = error.toString() ?? "Unknown JavaScript error"
            Logger.shared.log("Promise rejected: \(errorMessage)", type: "Error")
            DispatchQueue.main.async {
                completion((nil, nil, nil))
            }
        }
        
        thenFunction = JSValue(object: thenBlock, in: context)
        catchFunction = JSValue(object: catchBlock, in: context)

        guard let thenFunction, let catchFunction else {
            Logger.shared.log("Failed to create JSValue objects for Promise handling", type: "Error")
            completion((nil, nil, nil))
            return
        }
        
        promise.invokeMethod("then", withArguments: [thenFunction])
        promise.invokeMethod("catch", withArguments: [catchFunction])
    }
}
