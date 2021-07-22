//
//  Time+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-05.
//

import Foundation

internal extension Timer {
    @discardableResult
    static func duration<R>(of block: @autoclosure () throws -> R,
                            timeCallback: (TimeInterval, R?, Error?) -> Void) rethrows -> R {
        var err: Error? = nil
        var rtn: R? = nil
        let startTime = Date()
        defer {
            timeCallback(startTime.timeIntervalSinceNow.magnitude, rtn, err)
        }
        do {
            rtn = try block()
            return rtn!
        } catch {
            err = error
            throw error
        }
    }
    
    @discardableResult
    static func debugDuration<R>(of block: @autoclosure () throws -> R,
                                 timeCallback: (TimeInterval, R?, Error?) -> Void) rethrows -> R {
        return try self.duration(of: block()) { duration, results, err in
            #if DEBUG
            timeCallback(duration, results, err)
            #endif
        }
        
    }
    
    
    
    @discardableResult
    static func xcodeDuration<R>(of block: @autoclosure () throws -> R,
                            timeCallback: (TimeInterval, R?, Error?) -> Void) rethrows -> R {
        return try self.debugDuration(of: block()) { duration, results, err in
            if (ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil) {
                timeCallback(duration, results, err)
            }
        }
    }
}
