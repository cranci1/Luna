//
//  KanzenRunnerController.swift
//  Kanzen
//
//  Created by Dawud Osman on 12/05/2025.
//
import Foundation
import JavaScriptCore
class KanzenRunnerController
{
    private let moduleRunner: KanzenModuleRunner
    private let outputFormatter: KanzenOutputFormatter
    init(moduleRunner: KanzenModuleRunner, outputFormatter: KanzenOutputFormatter) {
        self.moduleRunner = moduleRunner
        self.outputFormatter = outputFormatter
    }
    func loadScript(_script: String) throws
    {
        try moduleRunner.loadScript(_script)
    }
    func getChapterImages(params:Any,completion: @escaping ([String]?) -> Void)
    {
        moduleRunner.getChapterImages(params: params)
        {
            jsResult, error in
            guard let result = jsResult?.toArray() as? [String] else {
                completion(nil)
                return
            }
            completion(result)
        }
    }
    func getChapters(params:Any, completion: @escaping ([String:Any]?) -> Void )
    {
        moduleRunner.getChapters(params: params){
            jsResult, error in
            guard let result = jsResult?.toDictionary() as? [String:Any] else
            {
                completion(nil)
                return
            }
            completion(result)
        }
    }
    func getContentData(params:Any, completion: @escaping ([String:Any]?)-> Void)
    {
       
        moduleRunner.getContentData(params: params)
        {
            jsResult, error in
            guard let result = jsResult?.toDictionary() as? [String:Any] else
            {
                completion(nil)
                return
            }
            completion(result)
        }
    }
    func searchInput(_input: String,page:Int = 0, completion: @escaping ([[String:Any]]?) -> Void)
    {
        moduleRunner.searchContent(input: _input,page: page)
        {
            jsResult,error in
            guard let result = jsResult?.toArray() as? [[String:Any]] else {
                completion(nil)
                return
            }
            completion(result)
            
        }
    }
}

