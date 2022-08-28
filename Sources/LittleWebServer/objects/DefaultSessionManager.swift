//
//  DefaultSessionManager.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-17.
//

import Foundation
import Dispatch
import SynchronizeObjects

internal extension LittleWebServer {
    /// The default session manager.  Used for containing clients sessions
    class DefaultSessionManager: LittleWebServerSessionManager {
        
        class Session: LittleWebServerSession {
            internal var lastModified: Date
            public let id: String
            private var data: [String: Codable]
            
            public var count: Int { return self.data.count}
            
            public private(set) var isInvalidated: Bool = false
            
            public subscript(key: String) -> Codable? {
                get { return self.data[key] }
                set { self.data[key] = newValue }
            }
            public init() {
                self.lastModified = Date()
                self.id = UUID().uuidString
                self.data = [:]
            }
            
            public init(lastModified: Date = Date(),
                        id: String,
                        data: [String: Codable]) {
                self.lastModified = lastModified
                self.id = id
                self.data = data
            }
            
            fileprivate init(copy: Session) {
                self.lastModified = copy.lastModified
                self.id = copy.id
                self.data = copy.data
            }
            
            deinit {
                self.invalidate()
            }
            
            fileprivate func invalidate() {
                self.data = [:]
                self.isInvalidated = true
            }
        }
        
        
        public var sessionTimeOutLimit: TimeInterval = 600.0 // 10 min
        private let sessions: SyncLockObj<[Session]> = .init(value: [])
        private let sessionInvalidatorQueueRepeatTime: TimeInterval = 60.0
        private let sessionInvalidatorQueue = DispatchQueue(label: "LittleWebServer.DefaultSessionManager.sessionInvalidatorQueue", qos: .background)
        
        public var eventHandlersQueue = DispatchQueue(label: "LittleWebServer.DefaultSessionManager.eventHandlers.sync")
        public var sessionExpiredEventHandler: ((LittleWebServerSession) -> Void)? = nil
        public var invalidatingSessionEventHandler: ((LittleWebServerSession) -> Void)? = nil
        
        
        public init() {
            self.scheduleSessionChecker()
        }
        
        private func checkSessions() {
            self.sessions.lockingForWithValue { ptr in
            
                var index = ptr.pointee.startIndex
                while index < ptr.pointee.endIndex  {
                    let session = ptr.pointee[index]
                    if Date().timeIntervalSince(session.lastModified) > self.sessionTimeOutLimit {
                        ptr.pointee.remove(at: index)
                        let copySession = Session(copy: session)
                        self.eventHandlersQueue.async {
                            self.sessionExpiredEventHandler?(copySession)
                            self.invalidatingSessionEventHandler?(copySession)
                            copySession.invalidate()
                        }
                        session.invalidate()
                    } else {
                        index = ptr.pointee.index(after: index)
                    }
                }
            }
            
        }
        
        private func scheduleSessionChecker() {
            self.sessionInvalidatorQueue.asyncAfter(deadline: .now() + self.sessionInvalidatorQueueRepeatTime) { [weak self] in
                guard let s = self else { return }
                s.checkSessions()
                s.scheduleSessionChecker()
            }
        }
        
        public func createSession() -> LittleWebServerSession {
            let rtn = Session()
            self.sessions.append(rtn)
            return rtn
        }
        
        public func getSession(withId id: String) -> LittleWebServerSession? {
            guard let rtn = self.sessions.first(where: { return $0.id == id }) else {
                return nil
            }
            rtn.lastModified = Date()
            return rtn
        }
        
        public func findSession(withIds ids: [String]) -> LittleWebServerSession? {
            guard ids.count > 0 else { return nil }
            
            guard let rtn = self.sessions.first(where: { return ids.contains($0.id) }) else {
                return nil
            }
            
            rtn.lastModified = Date()
            return rtn
        }
        
        public func saveSession(_ session: LittleWebServerSession) {
            guard let s = session as? Session else { return }
            s.lastModified = Date()
            
            self.sessions.lockingForWithValue { ptr in
                if !ptr.pointee.contains(where: { return $0.id == s.id }) {
                    ptr.pointee.append(s)
                }
            }
        }
        
        public func removeSession(withId id: String) {
            self.sessions.lockingForWithValue { ptr in
                ptr.pointee.removeAll { session in
                    guard session.id == id else { return false }
                    let copySession = Session(copy: session)
                    self.eventHandlersQueue.async {
                        self.invalidatingSessionEventHandler?(copySession)
                        copySession.invalidate()
                    }
                    session.invalidate()
                    return true
                }
            }
        }
    }
}
