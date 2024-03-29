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
    /// The max number of workers to allow accross the different worker queues
    var maxTotalWorkerCount: Int { get set }
    /// The total number of running workers at any given moment
    var totalWorkerCount: UInt { get }
    /// Dictionary of the max number of workers allowed for each worker queue
    var maxWorkerCounts: [LittleWebServer.WorkerQueue: Int] { get set }
    /// The amount of time to wailt while stopping a thread before killing it
    var threadStopTimeout: TimeInterval { get set }
    
    /// Handler for an incomming connection
    /// - Parameters:
    ///   - client: The client connection used for reading/writing
    ///   - listener: The listener this connection came from
    ///   - server: The server this connection is running on
    ///   - sessionManager: The session manager the server is using
    ///   - signalServerEvent: Callback used to receive information of events have occured
    ///   - event: The server event that occured
    ///   - signalServerError: Callback used when there was an error when writing
    ///   - error: The error that occured while writing
    ///   - file: The path to the file the error occured
    ///   - line:THe line in the file the error occured
    func onAcceptedClient(_ client: LittleWebServerClient,
                          from listener: LittleWebServerListener,
                          server: LittleWebServer,
                          sessionManager: LittleWebServerSessionManager,
                          signalServerEvent: @escaping (_ event: LittleWebServer.ServerEvent) -> Void,
                          signalServerError: @escaping (_ error: Error,
                                                        _ file: String,
                                                        _ line: Int) -> Void)
    /// Wait method to wait when a given worker queue is available for a new process
    /// - Parameters:
    ///   - queue: The woker queue to wait for
    ///   - server: The server the woker queue is on
    func waitForQueueToBeAvailable(queue: LittleWebServer.WorkerQueue,
                                   on server: LittleWebServer)
    
    /// Method to tell the communicator that the server is shutting down
    func serverStopping()
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
    /// The amount of time to wailt while stopping a thread before killing it
    var threadStopTimeout: TimeInterval { get set }
    
    /// Handler for an incomming connection
    /// - Parameters:
    ///   - client: The client connection used for reading/writing
    ///   - listener: The listener this connection came from
    ///   - server: The server this connection is running on
    ///   - sessionManager: The session manager the server is using
    ///   - signalServerEvent: Callback used to receive information of events have occured
    ///   - event: The server event that occured
    ///   - signalServerError: Callback used when there was an error when writing
    ///   - error: The error that occured while writing
    ///   - file: The path to the file the error occured
    ///   - line:THe line in the file the error occured
    func onAcceptedClient(_ client: LittleWebServerClient,
                          from listener: LittleWebServerListener,
                          server: LittleWebServer,
                          sessionManager: LittleWebServerSessionManager,
                          signalServerEvent: @escaping (_ event: LittleWebServer.ServerEvent) -> Void,
                          signalServerError: @escaping (_ error: Error,
                                                        _ file: String,
                                                        _ line: Int) -> Void)
    /// Wait method to wait when a given worker queue is available for a new process
    /// - Parameters:
    ///   - queue: The woker queue to wait for
    ///   - server: The server the woker queue is on
    func waitForQueueToBeAvailable(queue: LittleWebServer.WorkerQueue,
                                   on server: LittleWebServer)
    
    /// Method to tell the communicator that the server is shutting down
    func serverStopping()
}
#endif
