//
//  ErrorDefinitions.swift
//  Kanzen
//
//  Created by Dawud Osman on 12/05/2025.
//

import Foundation

enum ScriptExecutionError: Error,CustomStringConvertible {
    case jsRuntimeError(String)   // JavaScript runtime error with a message
    case invalidReturnValue      // The script returned an invalid value
    case scriptLoadError(String) // Failed to load a script (e.g., file not found)
    // Custom description for printing
    var description: String {
        switch self {
        case .jsRuntimeError(let message):
            return "JavaScript Runtime Error: \(message)"
        case .invalidReturnValue:
            return "Invalid Return Value from script"
        case .scriptLoadError(let message):
            return "Script Load Error: \(message)"
        }
    }
}

// Module Creation ERRORS
enum ModuleCreationError: Error,CustomStringConvertible {
    case invalidScriptUrl(String)
    case moduleAlreadyExists(String)
    case invalidModuleName(String)
    var description: String {
        switch self {
        case .moduleAlreadyExists(let message):
            return "Module Already Exists: \(message)"
        case .invalidModuleName(let message):
            return "Invalid Module Name: \(message)"
        case .invalidScriptUrl(let message):
            return "Invalid Script URL: \(message)"
        }
    }
}

// LOADING MODULE ERRORS
enum ModuleLoadingError: Error,CustomStringConvertible {
    case moduleNotFound(String)
    case moduleDecodeError(String)
    case missingScriptPath(String)
    case scriptDownloadError(String)
    case invalidScriptFormat(String)
    
    var description: String {
        switch self
        {
        case.moduleNotFound(let message):
            return "Module Not Found: \(message)"
        case.moduleDecodeError(let message):
            return "Module Decode Error: \(message)"
        case.missingScriptPath(let message):
            return "Missing Script Path: \(message)"
        case.scriptDownloadError(let message):
            return "Script Download Error: \(message)"
        case.invalidScriptFormat(let message):
            return "Invalid Script Format: \(message)"
        }
    }
}
