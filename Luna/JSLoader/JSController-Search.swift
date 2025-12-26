//
//  JSController-Search.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import JavaScriptCore

struct SearchItem: Identifiable {
    let id = UUID()
    let title: String
    let imageUrl: String
    let href: String
}

extension JSController {
    func fetchJsSearchResults(keyword: String, module: Service, completion: @escaping ([SearchItem]) -> Void) {
        if let exception = context.exception {
            Logger.shared.log("JavaScript exception: \(exception)", type: "Error")
            completion([])
            return
        }
        
        guard let searchResultsFunction = context.objectForKeyedSubscript("searchResults") else {
            Logger.shared.log("Search function not found in module", type: "Error")
            completion([])
            return
        }
        
        let promiseValue = searchResultsFunction.call(withArguments: [keyword])
        guard let promise = promiseValue else {
            Logger.shared.log("Search function returned invalid response", type: "Error")
            completion([])
            return
        }
        
        let thenBlock: @convention(block) (JSValue) -> Void = { result in
            
            Logger.shared.log(result.toString(), type: "HTMLStrings")
            if let jsonString = result.toString(),
               let data = jsonString.data(using: .utf8) {
                do {
                    if let array = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        let resultItems = array.compactMap { item -> SearchItem? in
                            guard let title = item["title"] as? String,
                                  let imageUrl = item["image"] as? String,
                                  let href = item["href"] as? String else {
                                Logger.shared.log("Invalid search result data format", type: "Error")
                                return nil
                            }
                            return SearchItem(title: title, imageUrl: imageUrl, href: href)
                        }
                        
                        DispatchQueue.main.async {
                            completion(resultItems)
                        }
                        
                    } else {
                        Logger.shared.log("Could not parse JSON response", type: "Error")
                        DispatchQueue.main.async {
                            completion([])
                        }
                    }
                } catch {
                    Logger.shared.log("JSON parsing error: \(error)", type: "Error")
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            } else {
                Logger.shared.log("Invalid search result format", type: "Error")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
        
        let catchBlock: @convention(block) (JSValue) -> Void = { error in
            Logger.shared.log("Search operation failed: \(String(describing: error.toString()))", type: "Error")
            DispatchQueue.main.async {
                completion([])
            }
        }
        
        let thenFunction = JSValue(object: thenBlock, in: context)
        let catchFunction = JSValue(object: catchBlock, in: context)
        
        promise.invokeMethod("then", withArguments: [thenFunction as Any])
        promise.invokeMethod("catch", withArguments: [catchFunction as Any])
    }
}
