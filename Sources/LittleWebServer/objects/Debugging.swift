//
//  Debugging.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-07-10.
//

import Foundation

internal class Debugging {
    static var isInXcode: Bool {
        #if DEBUG
        return (ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil)
        #else
        return false
        #endif
    }
    
    private static func _print<Target>(items: [Any],
                                       separator: String = " ",
                                       terminator: String = "\n",
                                       to stream: inout Target) where Target: TextOutputStream {
        let msg = items.map({ return "\($0)"}).joined(separator: separator)
        stream.write(msg + terminator)
    }
    
    static func printIfXcode<Target>(_ items: Any...,
                                     separator: String = " ",
                                     terminator: String = "\n",
                                     to stream: inout Target) where Target: TextOutputStream {
        if isInXcode {
            self._print(items: items, separator: separator, terminator: terminator, to: &stream)
        }
    }
    
    static func printIfXcode(_ items: Any...,
                             separator: String = " ",
                             terminator: String = "\n") {
        
        if isInXcode {
            var line: String = ""
            self._print(items: items, separator: separator, terminator: terminator, to: &line)
            Swift.print(line, terminator: "")
        }
    }
    
    
}
