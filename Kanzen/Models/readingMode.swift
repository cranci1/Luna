//
//  readingMode.swift
//  Luna
//
//  Created by Dawud Osman on 17/11/2025.
//
//
//  readingMode.swift
//  Kanzen
//
//  Created by Dawud Osman on 04/10/2025.
//
enum ReadingMode: Int,CaseIterable,Identifiable {
    case LTR = 0
    case RTL = 1
    case WEBTOON =  2
    case VERTICAL = 3
    
    var id: Int{ rawValue}
    var title: String {
        switch self {
        case .LTR: return "Left to Right"
        case .RTL: return "Right to Left"
        case .WEBTOON: return "Webtoon"
        case .VERTICAL: return "Vertical"
        }
    }
}

enum pageViewMode: Int,CaseIterable {
    case LTR = 0
    case RTL = 1
    case Vertical = 2
    
}
