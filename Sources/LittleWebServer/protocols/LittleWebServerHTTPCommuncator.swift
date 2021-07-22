//
//  LittleWebServerHTTPCommuncator.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-20.
//

import Foundation

#if swift(>=5.4)
/// A protocol defining A HTTP Communicator like HTTP 1.1
/// This allows chaning the HTTP Communicator for different HTTP versions
public protocol LittleWebServerHTTPCommunicator: AnyObject {
    //var httpVersion: LittleWebServer.HTTP.Version { get }
    /// The max number of workers to allow accross the different worker queues
    var maxTotalWorkerCount: Int { get set }
    /// The total number of running workers at any given moment
    var totalWorkerCount: UInt { get }
    /// Dictionary of the max number of workers allowed for each worker queue
    var maxWorkerCounts: [LittleWebServer.WorkerQueue: Int] { get set }
    
    /// Handler for an incomming connection
    /// - Parameters:
    ///   - client: The client connection used for reading/writing
    ///   - listener: The listener this connection came from
    ///   - server: The server this connection is running on
    ///   - sessionManager: The session manager the server is using
    ///   - signalRequestResponseEvent: Callback used to receive information of what was written to the client
    ///   - event: The write reponse event
    ///   - signalServerError: Callback used when there was an error when writing
    ///   - error: The error that occured while writing
    ///   - file: The path to the file the error occured
    ///   - line:THe line in the file the error occured
    func onAcceptedClient(_ client: LittleWebServerClient,
                          from listener: LittleWebServerListener,
                          server: LittleWebServer,
                          sessionManager: LittleWebServerSessionManager,
                          signalRequestResponseEvent: @escaping (_ event: LittleWebServer.RequestResponseEvent) -> Void,
                          signalServerError: @escaping (_ error: Error,
                                                        _ file: String,
                                                        _ line: Int) -> Void)
    /// Wait method to wait when a given worker queue is available for a new process
    /// - Parameters:
    ///   - queue: The woker queue to wait for
    ///   - server: The server the woker queue is on
    func waitForQueueToBeAvailable(queue: LittleWebServer.WorkerQueue,
                                   on server: LittleWebServer)
}
#else
/// A protocol defining A HTTP Communicator like HTTP 1.1
/// This allows chaning the HTTP Communicator for different HTTP versions
public protocol LittleWebServerHTTPCommunicator: class {
    //var httpVersion: LittleWebServer.HTTP.Version { get }
    /// The max number of workers to allow accross the different worker queues
    var maxTotalWorkerCount: Int { get set }
    /// The total number of running workers at any given moment
    var totalWorkerCount: UInt { get }
    /// Dictionary of the max number of workers allowed for each worker queue
    var maxWorkerCounts: [LittleWebServer.WorkerQueue: Int] { get set }
    
    /// Handler for an incomming connection
    /// - Parameters:
    ///   - client: The client connection used for reading/writing
    ///   - listener: The listener this connection came from
    ///   - server: The server this connection is running on
    ///   - sessionManager: The session manager the server is using
    ///   - signalRequestResponseEvent: Callback used to receive information of what was written to the client
    ///   - event: The write reponse event
    ///   - signalServerError: Callback used when there was an error when writing
    ///   - error: The error that occured while writing
    ///   - file: The path to the file the error occured
    ///   - line:THe line in the file the error occured
    func onAcceptedClient(_ client: LittleWebServerClient,
                          from listener: LittleWebServerListener,
                          server: LittleWebServer,
                          sessionManager: LittleWebServerSessionManager,
                          signalRequestResponseEvent: @escaping (_ event: LittleWebServer.RequestResponseEvent) -> Void,
                          signalServerError: @escaping (_ error: Error,
                                                        _ file: String,
                                                        _ line: Int) -> Void)
    /// Wait method to wait when a given worker queue is available for a new process
    /// - Parameters:
    ///   - queue: The woker queue to wait for
    ///   - server: The server the woker queue is on
    func waitForQueueToBeAvailable(queue: LittleWebServer.WorkerQueue,
                                   on server: LittleWebServer)
}
#endif
