//
//  LittleWebServerListener.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-17.
//

import Foundation

/// Represents a Connection Listener
public protocol LittleWebServerListener: LittleWebServerConnection {
    /// The scheme of the connection (eg http, https, unix)
    var scheme: String { get }
    /// Indicator if the listener is currently listening
    var isListening: Bool { get }
    /// Start listening for incomming connection
    func startListening() throws
    /// Stop listening for incomming connections
    func stopListening()
    /// Accepts an incomming client connection
    func accept() throws -> LittleWebServerClient
    
    /*
    @discardableResult
    func reinitialize() throws -> Bool
    */
}
