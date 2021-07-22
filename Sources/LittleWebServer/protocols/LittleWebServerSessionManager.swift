//
//  LittleWebServerSessionManager.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-17.
//

import Foundation
import Dispatch

/// A Protocol defining a web server session
public protocol LittleWebServerSession {
    /// The unique ID for the session
    var id: String { get }
    /// An indicator if the session is invalidated
    var isInvalidated: Bool { get }
    /// The number of objects wihtin the session
    var count: Int { get }
    /// Access to get/set objects within the session
    subscript(key: String) -> Codable? { get set }
}

/// A Protocol defnining a web server session manager.
public protocol LittleWebServerSessionManager {
    /// The timeout for an inactive session
    var sessionTimeOutLimit: TimeInterval { get set }
    
    /// The queue to use when calling any of the event handlers
    var eventHandlersQueue: DispatchQueue { get set }
    /// Event handler called when a session has expired
    var sessionExpiredEventHandler: ((LittleWebServerSession) -> Void)? { get set }
    /// Event handler called when a session has been invalidated
    var invalidatingSessionEventHandler: ((LittleWebServerSession) -> Void)? { get set }
    
    /// Create a new session
    func createSession() -> LittleWebServerSession
    /// Get a session with the given id
    func getSession(withId: String) -> LittleWebServerSession?
    /// Get the first session with any of the following ids
    func findSession(withIds: [String]) -> LittleWebServerSession?
    /// Save the given session
    func saveSession(_ session: LittleWebServerSession)
    /// Remove the sesion with the given id from the system
    func removeSession(withId: String)
}

public extension LittleWebServerSessionManager {
    /// Remove the session from the system
    func removeSession(_ session: LittleWebServerSession) {
        self.removeSession(withId: session.id)
    }
}
