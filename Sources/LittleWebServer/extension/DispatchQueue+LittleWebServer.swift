//
//  DispatchQueue+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-08-09.
//

import Foundation
import Dispatch

internal extension DispatchQueue {
    /// Create new Dispatch Queue and execute block waiting for return or timeout
    static func new(label: String,
                    qos: DispatchQoS = .unspecified,
                    attributes: DispatchQueue.Attributes = [],
                    autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = .inherit,
                    target: DispatchQueue? = nil,
                    timeout: DispatchTime,
                    block: @escaping () -> Void) -> DispatchTimeoutResult {
        
        return DispatchQueue(label: label,
                      qos: qos,
                      attributes: attributes,
                      autoreleaseFrequency: autoreleaseFrequency,
                      target: target).asyncAndWait(timeout: timeout, execute: block)
    }
    
    /// Execute block asynchronously and wait until completed or timeout which ever comes first
    func asyncAndWait(timeout: DispatchTime, execute block: @escaping () -> Void) -> DispatchTimeoutResult {
        let semaphore = DispatchSemaphore(value: 0)
        self.async {
            block()
            semaphore.signal()
        }
        return semaphore.wait(timeout: timeout)
    }
}
