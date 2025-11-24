//
//  ModuleManager.swift
//  Kanzen
//
//  Created by Dawud Osman on 13/05/2025.
//
import Foundation
class ModuleManager: ObservableObject {
    static let shared = ModuleManager()
    @Published var modules: [ModuleDataContainer] = []
    private let fileManager = FileManager.default
    private let modulesFileName: String = "modules.json"
    private init()
    {
        createModuleFile()
        // loadModules
        loadModules()
        // validate Modules
        for module in modules {
            validateModule(module){isValid in
                if !isValid {
                    Logger.shared.log("Module \(module.moduleData.sourceName) is not valid", type: "Error")
                }
            }
        }
        print("Modules Called")
    }
    func saveModules()
    {
        DispatchQueue.main.async {
            let url = ModuleManager.shared.getModulesFilePath()
            guard let data = try? JSONEncoder().encode(self.modules) else {return}
            try? data.write(to: url)
            print("modules saved")
        }
    }
    func addModules(_ moduleUrL:String, metaData: ModuleData) async throws -> Void
    {
        // check if module exists already
        if modules.contains(where: {$0.moduleurl == moduleUrL})
        {
            throw  ModuleCreationError.moduleAlreadyExists("module already exists")
        }
        // validate and extra ModuleData (metaData)
        
        
        let jsContent = try await validateJSfile(metaData.scriptURL)
        let fileName = "\(UUID().uuidString).js"
        let localUrl = getDocumentsDirectory().appendingPathComponent(fileName)
        try jsContent.write(to: localUrl, atomically: true, encoding: .utf8)
        let module = ModuleDataContainer( moduleData: metaData, localPath: fileName, moduleurl: moduleUrL)
        DispatchQueue.main.async {
            ModuleManager.shared.modules.append(module)
            ModuleManager.shared.saveModules()
        }
        
    }
    func deleteModule(_ module: ModuleDataContainer)
    {
        let fileUrl = getDocumentsDirectory().appendingPathComponent(modulesFileName)
        try? fileManager.removeItem(at: fileUrl)
        ModuleManager.shared.modules.removeAll(where: {$0.id == module.id})
        ModuleManager.shared.saveModules()
        
    }
    func getModulesFilePath() -> URL
    {
        getDocumentsDirectory().appendingPathComponent(modulesFileName)
    }
    func getModuleScript(module: ModuleDataContainer) throws -> String{
        let localUrl = getDocumentsDirectory().appendingPathComponent(module.localPath)
        return try String(contentsOf: localUrl, encoding: .utf8)
    }
    func createModuleFile()
    {
        let fileUrl = getDocumentsDirectory().appendingPathComponent(modulesFileName)
        if(!fileManager.fileExists(atPath: fileUrl.path))
        {
            do {
                try "[]".write(to:fileUrl,atomically: true,encoding: .utf8)
                Logger.shared.log("Created new modules file",type: "Info")
            }
            catch {
                Logger.shared.log("Failed to create modules file: \(error.localizedDescription)", type: "Error")
            }
        }
    }
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    func loadModules()
    {
        let fileUrl = getDocumentsDirectory().appendingPathComponent(modulesFileName)
        do
        {
            let data = try Data(contentsOf: fileUrl)
            let decodedModules = try JSONDecoder().decode([ModuleDataContainer].self, from: data)
            modules = decodedModules
            
        }
        catch
        {
            modules = []
            Logger.shared.log(ModuleLoadingError.moduleDecodeError(error.localizedDescription).localizedDescription,type: "Error")
            
        }
        
    }
    func validateJSfile(_ url: String)  async throws -> String
    {
        
        
            guard let scriptUrl = URL(string: url) else {
                throw ModuleLoadingError.invalidScriptFormat("Invalid Script Url")
               
            }
       
            let (scriptData,_)  = try await URLSession.shared.data(from: scriptUrl)
            guard let jsContent = String(data:scriptData, encoding: .utf8) else
            {
                throw ModuleLoadingError.invalidScriptFormat("Invalid Script Format")
            }
            
            return jsContent
        
       
    }
    func validateModuleUrl(_ urlString: String) async throws -> ModuleData
    {
        do{
            guard let url =  URL(string: urlString) else
            {
                throw  ModuleCreationError.invalidScriptUrl("invalid Script URL")
            }
            let (rawData,_) = try await URLSession.shared.data(from: url)
            let metaData = try JSONDecoder().decode(ModuleData.self, from: rawData)
           return metaData
        }
        catch{
            throw error
            
        }
    }
    func validateModule(_ module: ModuleDataContainer, completion: @escaping (Bool) -> Void)
    { Task
        {
            do  {
               
                let fileUrl = getDocumentsDirectory().appendingPathComponent(module.localPath)
                
                let validFilePath =  fileManager.fileExists(atPath: fileUrl.path)
              
                if(!validFilePath)
                {
                    Logger.shared.log("downloading js file for: \(module.moduleData.sourceName)")
                    let validJsContent = try await validateJSfile(module.moduleData.scriptURL)
                    try validJsContent.write(to:fileUrl,atomically: true, encoding: .utf8 )
                }
                completion(true)
                
                
            }
            catch  {
                Logger.shared.log("Module Validation Error: (\(module.moduleData.sourceName)) \(error.localizedDescription)",type: "Error")
                completion(false)
               
            }
           
        }
        }
    func getModule(_ moduleId: UUID) -> ModuleDataContainer?
    {
        return ModuleManager.shared.modules.first { $0.id == moduleId }
    }
    

    
}
