//
//  KanzenEngine.swift
//  Kanzen
//
//  Created by Dawud Osman on 12/05/2025.
//
import SwiftUI
class KanzenEngine: ObservableObject
{
    private let controller: KanzenRunnerController
    init() {
        Logger.shared.log("Launching Kanzen Engine",type: "General")
       let moduleRunner = KanzenModuleRunner()
        let outputFormatter = KanzenOutputFormatter()
        self.controller = KanzenRunnerController(moduleRunner: moduleRunner, outputFormatter: outputFormatter)
        Logger.shared.log("Successfully Kanzen Launched Engine",type: "General")
    }
    func loadScript(_ script: String) throws {
        Logger.shared.log("Loading Module Script",type: "General")
         try self.controller.loadScript(_script: script)
        Logger.shared.log("Successfully  Loaded Module Script",type: "General")
    }
    func getContentData(params:Any?, completion: @escaping ([String:Any]?) -> Void)
    {
        controller.getContentData(params: params)
        {
            result in

            completion(result)
        }
    }
    func getChapterImages(params:Any?, completion: @escaping ([String]?)-> Void)
    {
        
        controller.getChapterImages(params: params){
            result in
            completion(result)
        }
    }
    func getChapters(params: Any?, completion: @escaping ([String:Any]?)-> Void)
    {
        controller.getChapters(params: params){
            result in
            completion(result)
        }
    }
    func searchInput(_ input: String,page: Int = 0, completion: @escaping ([[String:Any]]?) -> Void) -> Void {
        controller.searchInput(_input: input,page: page)
        {
            result in
            
            completion(result)
            
        }
    }
}
