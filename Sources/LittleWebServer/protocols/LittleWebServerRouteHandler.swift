//
//  LittleWebServerRouteHandler.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-30.
//

import Foundation

public protocol LittleWebServerRouteHandler {
    
    var hasRouteHandler: Bool { get }
    
    init()
}

extension Optional: LittleWebServerRouteHandler {
    public var hasRouteHandler: Bool {
        guard case .some(_) = self else { return false }
        return true
    }
    public init() { self = .none }
}

extension Array: LittleWebServerRouteHandler {
    public var hasRouteHandler: Bool {
        return !self.isEmpty
    }
}

