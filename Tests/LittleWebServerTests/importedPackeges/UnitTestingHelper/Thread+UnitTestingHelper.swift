//
//  Thread+UnitTestingHelper.swift
//  UnitTestingHelper
//
//  Created by Tyler Anger on 2020-11-07.
//

import Foundation

internal extension Thread {
    enum PrintOverride {
        case none
        case override
        case disable
        
        internal func canPrint(_ value: Bool) -> Bool {
            switch self {
            case .none: return value
            case .override: return true
            case .disable: return false
            }
            
        }
    }
    
    private enum OverrideKeys: String {
        case print = "UnitTestingHelper.print.override"
        case verbosePrint = "UnitTestingHelper.verbosePrint.override"
        case debugPrint = "UnitTestingHelper.debugPrint.override"
    }
    var overrideCanPrint: PrintOverride {
        get {
            return (self.threadDictionary[OverrideKeys.print.rawValue] as? PrintOverride) ?? .none
        }
        set {
            guard newValue != .none else {
                self.threadDictionary[OverrideKeys.print.rawValue] = nil
                return
            }
            self.threadDictionary[OverrideKeys.print.rawValue] = newValue
        }
    }
    var overrideCanVerbosePrint: PrintOverride {
        get {
            return (self.threadDictionary[OverrideKeys.verbosePrint.rawValue] as? PrintOverride) ?? .none
        }
        set {
            guard newValue != .none else {
                self.threadDictionary[OverrideKeys.verbosePrint.rawValue] = nil
                return
            }
            self.threadDictionary[OverrideKeys.verbosePrint.rawValue] = newValue
        }
    }
    var overrideCanDebugPrint: PrintOverride {
        get {
            return (self.threadDictionary[OverrideKeys.debugPrint.rawValue] as? PrintOverride) ?? .none
        }
        set {
            guard newValue != .none else {
                self.threadDictionary[OverrideKeys.debugPrint.rawValue] = nil
                return
            }
            self.threadDictionary[OverrideKeys.debugPrint.rawValue] = newValue
        }
    }
}
