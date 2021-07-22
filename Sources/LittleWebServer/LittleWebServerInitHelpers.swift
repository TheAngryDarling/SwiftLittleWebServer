//
//  LittleWebServerInitHelpers.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-20.
//

import Foundation

public extension LittleWebServer {
    /// Create a new LittleWebServer instance
    ///
    /// Note: This init will use the DefaultSessionManager to manage web sessions
    ///
    /// - Parameters:
    ///   - listeners: A list of listeners the web server will be listening on
    ///   - maxRequestWorkerCount: The maximum number of workers to use for generate requests.  -1 equals no limit, 0 will stop pause anymore processing
    ///   - maxWorkerQueueCounts: The max number of workers for all the different worker queues. 1 equals no limit, 0 will stop pause anymore processing
    ///   - httpCommunicator: The HTTP Communicator to use to communicate with clients
    convenience init(_ listeners: [LittleWebServerListener] = [],
                     maxRequestWorkerCount: Int = LittleWebServer.DEFAULT_WORKER_COUNT,
                     maxWorkerQueueCounts: [LittleWebServer.WorkerQueue: Int] = [:],
                     httpCommunicator: LittleWebServerHTTPCommunicator) {
        self.init(listeners,
                  maxRequestWorkerCount: maxRequestWorkerCount,
                  maxWorkerQueueCounts: maxWorkerQueueCounts,
                  sessionManager: DefaultSessionManager(),
                  httpCommunicator: httpCommunicator)
    }
    
    /// Create a new LittleWebServer instance
    ///
    /// Note: This init will use the DefaultSessionManager to manage web sessions
    ///
    /// - Parameters:
    ///   - listeners: A list of listeners the web server will be listening on
    ///   - maxRequestWorkerCount: The maximum number of workers to use for generate requests.  -1 equals no limit, 0 will stop pause anymore processing
    ///   - maxWorkerQueueCounts: The max number of workers for all the different worker queues. 1 equals no limit, 0 will stop pause anymore processing
    ///   - httpCommunicator: The HTTP Communicator to use to communicate with clients
    convenience init(_ listeners: LittleWebServerListener...,
                     maxRequestWorkerCount: Int = LittleWebServer.DEFAULT_WORKER_COUNT,
                     maxWorkerQueueCounts: [LittleWebServer.WorkerQueue: Int] = [:],
                     httpCommunicator: LittleWebServerHTTPCommunicator) {
        self.init(listeners,
                  maxRequestWorkerCount: maxRequestWorkerCount,
                  maxWorkerQueueCounts: maxWorkerQueueCounts,
                  sessionManager: DefaultSessionManager(),
                  httpCommunicator: httpCommunicator)
    }
    
    /// Create a new LittleWebServer instance
    ///
    /// Note: This uses the LittleWebServer.HTTP.Communicators.V1_1 HTTP Communicator
    ///
    /// - Parameters:
    ///   - listeners: A list of listeners the web server will be listening on
    ///   - maxRequestWorkerCount: The maximum number of workers to use for generate requests.  -1 equals no limit, 0 will stop pause anymore processing
    ///   - maxWorkerQueueCounts: The max number of workers for all the different worker queues. 1 equals no limit, 0 will stop pause anymore processing
    ///   - sessionManager: The session manager to use to manage all web sessions
    convenience init(_ listeners: [LittleWebServerListener] = [],
                     maxRequestWorkerCount: Int = LittleWebServer.DEFAULT_WORKER_COUNT,
                     maxWorkerQueueCounts: [LittleWebServer.WorkerQueue: Int] = [:],
                     sessionManager: LittleWebServerSessionManager) {
        self.init(listeners,
                  maxRequestWorkerCount: maxRequestWorkerCount,
                  maxWorkerQueueCounts: maxWorkerQueueCounts,
                  sessionManager: sessionManager,
                  httpCommunicator: LittleWebServer.HTTP.Communicators.V1_1())
    }
    
    /// Create a new LittleWebServer instance
    ///
    /// Note: This uses the LittleWebServer.HTTP.Communicators.V1_1 HTTP Communicator
    ///
    /// - Parameters:
    ///   - listeners: A list of listeners the web server will be listening on
    ///   - maxRequestWorkerCount: The maximum number of workers to use for generate requests.  -1 equals no limit, 0 will stop pause anymore processing
    ///   - maxWorkerQueueCounts: The max number of workers for all the different worker queues. 1 equals no limit, 0 will stop pause anymore processing
    ///   - sessionManager: The session manager to use to manage all web sessions
    convenience init(_ listeners: LittleWebServerListener...,
                     maxRequestWorkerCount: Int = LittleWebServer.DEFAULT_WORKER_COUNT,
                     maxWorkerQueueCounts: [LittleWebServer.WorkerQueue: Int] = [:],
                     sessionManager: LittleWebServerSessionManager) {
        self.init(listeners,
                  maxRequestWorkerCount: maxRequestWorkerCount,
                  maxWorkerQueueCounts: maxWorkerQueueCounts,
                  sessionManager: sessionManager,
                  httpCommunicator: LittleWebServer.HTTP.Communicators.V1_1())
    }
    
    /// Create a new LittleWebServer instance
    ///
    /// Note: This uses the LittleWebServer.HTTP.Communicators.V1_1 HTTP Communicator
    /// This init will use the DefaultSessionManager to manage web sessions
    ///
    /// - Parameters:
    ///   - listeners: A list of listeners the web server will be listening on
    ///   - maxRequestWorkerCount: The maximum number of workers to use for generate requests.  -1 equals no limit, 0 will stop pause anymore processing
    ///   - maxWorkerQueueCounts: The max number of workers for all the different worker queues. 1 equals no limit, 0 will stop pause anymore processing
    convenience init(_ listeners: [LittleWebServerListener] = [],
                     maxRequestWorkerCount: Int = LittleWebServer.DEFAULT_WORKER_COUNT,
                     maxWorkerQueueCounts: [LittleWebServer.WorkerQueue: Int] = [:]) {
        self.init(listeners,
                  maxRequestWorkerCount: maxRequestWorkerCount,
                  maxWorkerQueueCounts: maxWorkerQueueCounts,
                  sessionManager: DefaultSessionManager(),
                  httpCommunicator: LittleWebServer.HTTP.Communicators.V1_1())
    }
    /// Create a new LittleWebServer instance
    ///
    /// Note: This uses the LittleWebServer.HTTP.Communicators.V1_1 HTTP Communicator
    /// This init will use the DefaultSessionManager to manage web sessions
    ///
    /// - Parameters:
    ///   - listeners: A list of listeners the web server will be listening on
    ///   - maxRequestWorkerCount: The maximum number of workers to use for generate requests.  -1 equals no limit, 0 will stop pause anymore processing
    ///   - maxWorkerQueueCounts: The max number of workers for all the different worker queues. 1 equals no limit, 0 will stop pause anymore processing
    convenience init(_ listeners: LittleWebServerListener...,
                     maxRequestWorkerCount: Int = LittleWebServer.DEFAULT_WORKER_COUNT,
                     maxWorkerQueueCounts: [LittleWebServer.WorkerQueue: Int] = [:]) {
        self.init(listeners,
                  maxRequestWorkerCount: maxRequestWorkerCount,
                  maxWorkerQueueCounts: maxWorkerQueueCounts,
                  sessionManager: DefaultSessionManager(),
                  httpCommunicator: LittleWebServer.HTTP.Communicators.V1_1())
    }
}
