//
//  HTTPCommunicatorV1_1.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-20.
//

import Foundation
import Dispatch

public extension LittleWebServer.HTTP.Communicators {
    /// A HTTP/1.1 Server
    class V1_1: LittleWebServerHTTPCommunicator {
        
        public let httpVersion: LittleWebServer.HTTP.Version = .v1_1
        
        private var queueSyncList: [LittleWebServer.WorkerQueue: DispatchQueue] = [:]
        private let queueSyncListSync = DispatchQueue(label: "LittleWebServer.queueSyncList.sync")
        
        private var queueList: [LittleWebServer.WorkerQueue: OperationQueue] = [:]
        private let queuesListSync = DispatchQueue(label: "LittleWebServer.queueList.sync")
        
        private var queueOprationCount: [LittleWebServer.WorkerQueue: UInt] = [:]
        private let queueOprationCountSync = DispatchQueue(label: "LittleWebServer.queueOprationCount.sync")
        
        private var _maxWorkerCounts: [LittleWebServer.WorkerQueue: Int] = [:] {
            willSet {
                guard let requestCount = newValue[.request] else {
                    preconditionFailure("Missing Count for  worker queue Request")
                }
                precondition(requestCount == -1 || requestCount > 0,
                             "Max '\(LittleWebServer.WorkerQueue.request)' Worker Queue Count must be -1 or greater than 0")
                
                for (key, val) in newValue {
                    guard key != .request else {
                        continue
                    }
                    
                    precondition(requestCount >= -1,
                                 "Max '\(val)' Worker Queue Count must be >= -1")
                    
                }
            }
        }
        private let maxWorkerCountsLock = NSLock()
        public var maxWorkerCounts: [LittleWebServer.WorkerQueue: Int] {
            get {
                self.maxWorkerCountsLock.lock()
                defer { self.maxWorkerCountsLock.unlock() }
                return self._maxWorkerCounts
            }
            set {
                self.maxWorkerCountsLock.lock()
                defer { self.maxWorkerCountsLock.unlock() }
                self._maxWorkerCounts = newValue
            }
        }
        
        public var maxTotalWorkerCount: Int = -1
        public var totalWorkerCount: UInt {
            return self.queueOprationCountSync.sync {
                self.queueOprationCount.reduce(0, { return $0 + $1.value })
            }
        }
        
        func getTotalWorkerCount() -> UInt? {
            return self.totalWorkerCount
        }
        
        private func getWorkerCount(for queue: LittleWebServer.WorkerQueue) -> UInt {
            return self.queueOprationCountSync.sync {
                return self.queueOprationCount[queue] ?? 0
            }
        }
        
        private func incrementWorkerCount(for queue: LittleWebServer.WorkerQueue) {
            self.queueOprationCountSync.sync {
                let val = self.queueOprationCount[queue] ?? 0
                self.queueOprationCount[queue] = val + 1
            }
        }
        
        private func decrementWorkerCount(for queue: LittleWebServer.WorkerQueue) {
            self.queueOprationCountSync.sync {
                var val = self.queueOprationCount[queue] ?? 0
                if val > 0 { val -= 1 }
                self.queueOprationCount[queue] = val
            }
        }
        
        
        private func getOperationQueue(for queue: LittleWebServer.WorkerQueue) -> OperationQueue {
            return self.queueSyncListSync.sync {
                if let q = self.queueList[queue] {
                    return q
                } else {
                    let q = OperationQueue()
                    self.queueList[queue] = q
                    return q
                }
            }
        }
        
        private func getQueueSyncLock(for queue: LittleWebServer.WorkerQueue) -> DispatchQueue {
            return self.queueSyncListSync.sync {
                if let dq = self.queueSyncList[queue] {
                    return dq
                } else {
                    let dq = DispatchQueue(label: "LittleWebServer.queueSyncList[\(queue)].sync")
                    self.queueSyncList[queue] = dq
                    return dq
                }
            }
        }
        
        
        
        private func getMaxWorkerCount(for queue: LittleWebServer.WorkerQueue) -> Int? {
            return self.maxWorkerCounts[queue] ?? -1
        }
        
        public func waitForQueueToBeAvailable(queue: LittleWebServer.WorkerQueue,
                                              on server: LittleWebServer) {
            let dq = getQueueSyncLock(for: queue)
            dq.sync {
                
                          // get the max worker count each time
                while let mxWorkerCount = self.getMaxWorkerCount(for: queue),
                      let totalWorkerCount = self.getTotalWorkerCount(),
                      (
                          (
                            // If max worker count == -1, means no maximum
                            mxWorkerCount > -1 &&
                            // if current count > max count
                            mxWorkerCount <= self.getWorkerCount(for: queue)
                          )
                        || // OR
                          (
                            // If maxTotalWorkerCount == -1, means no maximum
                            self.maxTotalWorkerCount > -1 &&
                            self.maxTotalWorkerCount <= totalWorkerCount
                          )
                      ) &&
                      !server.isStoppingOrStopped &&
                      !Thread.current.isCancelled {
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        }
        
        /// Moves the processing of a request from the main request queue to a different queue
        /// - Parameters:
        ///   - queue: The queue to move the current processing to
        ///   - request: The request we're working on
        ///   - response: The response for the requeset
        ///   - uploadedFiles: Reference to any uploaded files for this request to be removed when done
        ///   - controller: The route controller used to process the request
        ///   - server: The server the request was made on
        ///   - sessionManager: The session manager being used
        ///   - client: The client connection the request came from
        ///   - signalRequestResponseEvent: Callback used to receive information of what was written to the client
        ///   - signalServerError: Callback used when there was an error when writing
        /// - Returns: Returns an indicator if the processing actually moved to a different queue
        private func hopToQueue(queue: LittleWebServer.HTTP.Response.ProcessQueue,
                                request: LittleWebServer.HTTP.Request,
                                response: LittleWebServer.HTTP.Response,
                                uploadedFiles: [LittleWebServer.HTTP.Request.UploadedFileReference],
                                in controller: LittleWebServer.Routing.Requests.RouteController,
                                server: LittleWebServer,
                                sessionManager: LittleWebServerSessionManager,
                                client: LittleWebServerClient,
                                signalRequestResponseEvent: @escaping (LittleWebServer.RequestResponseEvent) -> Void,
                                signalServerError: @escaping (Error, String, Int) -> Void) throws -> Bool {
            guard !queue.isCurrent else { return false }
            
           
            self.waitForQueueToBeAvailable(queue: queue.workerQueue, on: server)
            guard !server.isStoppingOrStopped && !Thread.current.isCancelled else {
                return false
            }
            
            self.getOperationQueue(for: queue.workerQueue).addOperation { [unowned self, server, response, client] in
                let oldServer = Thread.current.littleWebServerDetails.webServer
                defer { Thread.current.littleWebServerDetails.webServer = oldServer }
                Thread.current.littleWebServerDetails.webServer = server
                
                defer {
                    client.close()
                    for file in uploadedFiles {
                        try? FileManager.default.removeItem(at: file.location)
                    }
                }
                var hasPreviouslyWrittenHeaders: Bool = false
                do {
                    try self.write(request,
                                   response,
                                   in: controller,
                                   server: server,
                                   sessionManager: sessionManager,
                                   to: client,
                                   hasPreviouslyWrittenHeaders: &hasPreviouslyWrittenHeaders,
                                   keepAlive: true,
                                   signalRequestResponseEvent: signalRequestResponseEvent)
                } catch {
                    let err = LittleWebServer.WebRequestError.queueProcessError(queue,
                                                                                  .request(request,
                                                                                           connectionId: client.uid),
                                                                                  error)
                    #if swift(>=5.3)
                    signalServerError(err, #filePath, #line)
                    #else
                    signalServerError(err, #file, #line)
                    #endif
                }
            }
            
            return true
        }
        
        
        /// Write the response to the client connection
        /// - Parameters:
        ///   - request: The request we're working on
        ///   - response: The response for the requeset
        ///   - controller: The route controller used to process the request
        ///   - server: The server the request was made on
        ///   - sessionManager: The session manager being used
        ///   - client: The client connection the request came from
        ///   - hasPreviouslyWrittenHeaders: Indicator if a header has already been written for the given request (Could occur if includes where called)
        ///   - keepAlive: Indicator if the client connection should be kept alive
        ///   - signalRequestResponseEvent: Callback used to receive information of what was written to the client
        private func write(_ request: LittleWebServer.HTTP.Request?,
                           _ response: LittleWebServer.HTTP.Response,
                           in controller: LittleWebServer.Routing.Requests.RouteController,
                           server: LittleWebServer,
                           sessionManager: LittleWebServerSessionManager,
                           to client: LittleWebServerClient,
                           hasPreviouslyWrittenHeaders: inout Bool,
                           keepAlive: Bool? = nil,
                           signalRequestResponseEvent: (LittleWebServer.RequestResponseEvent) -> Void) throws {
            
            
            
            let startWriting = Date()
            defer {
                if Debugging.isInXcode {
                    let interval = (startWriting.timeIntervalSinceNow * -1)
                    print("Write response took \(interval) seconds")
                }
                
            }
            var workingHeaders = response.head.headers
            if let req = request {
                
                
                for sessionId in req.headers.cookies.sessionIds {
                    // Clear out any old lingering session ids
                    if sessionId != req.getSession(false)?.id {
                        workingHeaders.cookies.append(.init(expiredSessionId: sessionId))
                    }
                }
                
                if let session = req.getSession(false) {
                    if !session.isInvalidated {
                        
                        // We have a session thats not invalidated with content
                        
                        let dt = Date()
                        sessionManager.saveSession(session)
                        workingHeaders.cookies.append(.init(sessionId: session.id,
                                                            expires: dt + sessionManager.sessionTimeOutLimit,
                                                            maxAge: Int(sessionManager.sessionTimeOutLimit),
                                                            domain: req.headers.host?.name,
                                                            path: "/",
                                                            httpOnly: true))
                        
                    } else if !req.isNewSession && session.isInvalidated {
                        //  If we have an existing session, we tell the user to remove the cookie
                        workingHeaders.cookies.append(.init(expiredSessionId: session.id))
                        sessionManager.removeSession(session)
                    } else if req.isNewSession && session.count == 0 {
                        // this is a new unsued session. lets just remove it
                        sessionManager.removeSession(session)
                    }
                }
            }
            if workingHeaders.contentType == nil,
               let bodyContentType = response.body.contentType {
                workingHeaders.contentType = bodyContentType
            } else if workingHeaders.contentType == nil,
                      let filePath = response.body.filePath {
                if FileManager.default.fileExists(atPath: filePath) {
                    let ext = NSString(string: filePath).pathExtension
                    if let fileContentType = server.contentResourceType(forExtension: ext) {
                        workingHeaders.contentType = .init(fileContentType)
                    }
                }
            }
            
            if workingHeaders[.upgrade] == nil {
                if request == nil || request!.version == .v1_0 {
                    workingHeaders.connection = .close
                } else if let b = keepAlive, b {
                    workingHeaders.connection = .keepAlive
                    if self.httpVersion < .v2_0 {
                        workingHeaders.keepAlive = server.keepAliveDetails
                    }
                }
            }
            
            if let s = server.serverHeader {
                workingHeaders[.server] = s
            }
            
            workingHeaders[.date] = server.dateHeaderFormatter.string(from: .now)
            
            let bodyDetails = try response.body.content(in: controller, on: server)
            if let ctl = bodyDetails?.length/*, ctl > 0*/ {
                workingHeaders.contentLength = ctl //+ 2 // Add CRLF
            }
            
            if workingHeaders.contentLength == nil && workingHeaders[.upgrade] == nil {
                workingHeaders.transferEncodings += .chunked
                //workingHeaders.transferEncodings = ((workingHeaders.transferEncodings ?? .init())!) + .chunked
            }
            
            response.headers = workingHeaders
            
            
            
            if !hasPreviouslyWrittenHeaders {
                var msg = response.head.message ?? ""
                if !msg.isEmpty { msg = " " + msg }
                let respLine = "\(self.httpVersion.httpRespnseValue) \(response.head.responseCode)\(msg)"
                try client.writeUTF8Line(respLine)
                if !workingHeaders.isEmpty {
                    try client.writeUTF8(workingHeaders.http1xContent)
                }
                try client.writeUTF8Line("")
                hasPreviouslyWrittenHeaders = true
                
                //print(respLine)
                //print(workingHeaders.httpContent)
                
                signalRequestResponseEvent(.outgoingResposne(.init(response), for: request))
                
                
            }
            
            let writer = _LittleWebServerOutputStream(client: client,
                                                     transferEncodings: workingHeaders.transferEncodings)
            
            
            
            if bodyDetails != nil && bodyDetails!.content != nil {
                try writer.write(bodyDetails!.content!)
            } else if let pth = response.body.filePath,
                      let speedLimit = response.body.fileTransferSpeedLimit {
                try writer.writeContentsOfFile(atPath: pth, range: response.body.fileRange, speedLimit: speedLimit)
            } else if let custom = response.body.customBody {
                try custom(request?.inputStream ?? LittleWebServerEmptyInputStream(), writer)
            }
            
            
            //if let ctl = bodyDetails?.length, ctl > 0 {
            //if writer.isConnected {
            //    try writer.writeUTF8Line("")
            //}
            //}
            
        }
        
        public func onAcceptedClient(_ client: LittleWebServerClient,
                                     from listener: LittleWebServerListener,
                                     server: LittleWebServer,
                                     sessionManager: LittleWebServerSessionManager,
                                     signalRequestResponseEvent: @escaping (LittleWebServer.RequestResponseEvent) -> Void,
                                     signalServerError: @escaping (Error, String, Int) -> Void) {
            
            self.getOperationQueue(for: .request).addOperation { [server, client] in
            
                let oldServer = Thread.current.littleWebServerDetails.webServer
                defer { Thread.current.littleWebServerDetails.webServer = oldServer }
                Thread.current.littleWebServerDetails.webServer = server
                
                var hoppingQueue: Bool = false
                defer {
                    
                    if !hoppingQueue && client.isConnected {
                        client.close()
                    }
                }
                
                var keepAlive: Bool = true
                var firstRequest: Bool = true
                var requestCount: UInt = 0
                let maxRequestCount = (server.keepAliveDetails?.max ?? UInt.max)
                var sessionId: String? = nil
                
                while keepAlive && // while we want to keep the connection alive
                      client.isConnected && // while the socket is still connected
                      requestCount < maxRequestCount && // while we haven't reach the max requests per connection
                      !server.isStoppingOrStopped && 
                      !Thread.current.isCancelled { // If the thread is being cancelled.  Ususallay mans that we're shutting down
                    let startTime = Date()
                    defer {
                        if client.isConnected {
                            Debugging.printIfXcode("Request took \(startTime.timeIntervalSinceNow.magnitude) seconds")
                        }
                    }
                    let canContinue: Bool = autoreleasepool {
                        var uploadedFiles: [LittleWebServer.HTTP.Request.UploadedFileReference] = []
                        defer {
                            if !hoppingQueue {
                                for file in uploadedFiles {
                                    try? FileManager.default.removeItem(at: file.location)
                                }
                            }
                        }
                        var requestHead: LittleWebServer.HTTP.Request.Head! = nil
                        var headReadError: Error? = nil
                        var sentResponseHead: Bool = false
                        // We have a time limit for the first request to come in
                        if firstRequest && server.initialRequestTimeoutInSeconds > 0 {
                            let semaphore = DispatchSemaphore(value: 0)
                            DispatchQueue.global().async {
                                do {
                                    requestHead = try client.readRequestHead()
                                } catch {
                                    if client.isConnected {
                                        // error parsing request
                                        headReadError = error
                                    }
                                }
                                semaphore.signal()
                            }
                            
                            guard semaphore.wait(timeout: (.now() + server.initialRequestTimeoutInSeconds)) == .success else {
                                
                                server.signalServerError(error: LittleWebServer.WebRequestError.connectionTimedOut(.connectionId(client.uid)))
                                
                                client.close()
                                return false
                            }
                            if !client.isConnected {
                                return false
                            }
                            
                        } else {
                            do {
                                requestHead = try client.readRequestHead()
                            } catch {
                                if client.isConnected {
                                    // error parsing request
                                    print(error)
                                    headReadError = error
                                } else {
                                    return false
                                }
                            }
                        }
                        
                        guard let httpHead = requestHead else {
                            
                            server.signalServerError(error: LittleWebServer.WebRequestError.badRequest(.connectionId(client.uid), headReadError))
                            
                            if client.isConnected {
                                try? self.write(nil, LittleWebServer.HTTP.Response.badRequest(),
                                               in: server.defaultHost,
                                               server: server,
                                               sessionManager: sessionManager,
                                               to: client,
                                               hasPreviouslyWrittenHeaders: &sentResponseHead,
                                               signalRequestResponseEvent: signalRequestResponseEvent)
                            }
                            
                            
                            client.close()
                            keepAlive = false
                            return false
                        }
                        var request: LittleWebServer.HTTP.Request! = nil
                        var headers: LittleWebServer.HTTP.Request.Headers! = nil
                        let bodyInputStream = _LittleWebServerInputStream(client: client)
                        var contentLength: UInt? = nil
                        
                        // Indicator if we should kill connectioh
                        // If the current request has no specific content length
                        // We don't know when the request ends so we can't
                        // move on to the next.  Therefore the connection will
                        // be killed
                        var killConnection: Bool = false
                        var router: LittleWebServer.Routing.Requests.RouteController? = nil
                        
                        do {
                            headers = try client.readRequestHeaders()
                            if headers.connection == .close {
                                keepAlive = false
                            }
                            contentLength = headers.contentLength
                            bodyInputStream.chunked = headers.transferEncodings.contains(.chunked)
                            bodyInputStream.reportedContentLength = contentLength
                            
                            
                            let tempDirURL: URL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("LittleWebServer").appendingPathComponent(headers.host?.name.description ?? "default")
                           
                            if headers.contentType?.resourceType == .multiPartForm {
                                // Only check and create temp folder if the request is a multi-part
                                // content type
                                if !FileManager.default.fileExists(atPath: tempDirURL.path) {
                                    try? FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
                                }
                            }
                            
                            // Patch so that multiple session don't get created for each separate
                            // request on the same connection
                            if let sId = sessionId,
                               !headers.cookies.sessionIds.contains(sId) {
                                headers.cookies.sessionIds.append(sId)
                            }
                            
                            request = try Timer.xcodeDuration(of: try LittleWebServer.HTTP.Request.parse(scheme: listener.scheme,
                                                                                    head: httpHead,
                                                                                    headers: headers,
                                                                                    bodyStream: bodyInputStream,
                                                                                    uploadedFiles: &uploadedFiles,
                                                                                    tempLocation: tempDirURL)) { duration, r, _ in
                                
                                print("Parse request body took \(duration) seconds")
                                if let rq = r {
                                    print(rq.string)
                                }
                                
                            }
                            
                            sessionId = request.getSession(false)?.id
                            
                            signalRequestResponseEvent(.incomminRequest(request))
                            
                            
                            router = Timer.xcodeDuration(of: server.hosts.getRoutes(for: request,
                                                                              withDefault: server.defaultHost)) { duration, _, _ in
                                print("Getting router took \(duration) seconds")
                            }
                            
                            let response = try Timer.xcodeDuration(of: try router!.processRequest(for: request,
                                                                                             on: server)) { duration, _, _ in
                                print("Getting response took \(duration) seconds")
                            }
                            if (try self.hopToQueue(queue: response.writeQueue,
                                                    request: request,
                                                    response: response,
                                                    uploadedFiles: uploadedFiles,
                                                    in: router!,
                                                    server: server,
                                                    sessionManager: sessionManager,
                                                    client: client,
                                                    signalRequestResponseEvent: signalRequestResponseEvent,
                                                    signalServerError: signalServerError)) {
                                hoppingQueue = true
                                return false
                            } else {
                                try Timer.xcodeDuration(of: try self.write(request, response,
                                                                      in: router!,
                                                                      server: server,
                                                                      sessionManager: sessionManager,
                                                                      to: client,
                                                                      hasPreviouslyWrittenHeaders: &sentResponseHead,
                                                                      keepAlive: keepAlive,
                                                                      signalRequestResponseEvent: signalRequestResponseEvent)) { duration, _, _ in
                                    print("Writing response (\(response.head.responseCode) took \(duration) seconds")
                                    //print(response.head.string(for: server))
                                    //response
                                }
                            }
                            
                            if (request.getSession(false)?.isInvalidated ?? true) {
                                sessionId = nil
                            }
                            
                        } catch {
                            let requestIdentifier: LittleWebServer.WebRequestIdentifier
                            if let req = request {
                                requestIdentifier = .request(req, connectionId: client.uid)
                            } else {
                                requestIdentifier = .requestHead(httpHead, headers, connectionId: client.uid)
                            }
                            let processError: LittleWebServer.WebRequestError = .processRequestFailure(requestIdentifier,
                                                                                       serverIdentifier: listener.uid,
                                                                                       clientIdentifier: client.uid,
                                                                                       error: error)
                            server.signalServerError(error: processError)
                            
                            if client.isConnected {
                                do {
                                    
                                    let resp = (router ?? server.defaultHost).internalError(for: request,
                                                                                          error: error,
                                                                                          signalServerErrorHandler: false)
                                    
                                    
                                    try self.write(request, resp,
                                                   in: (router ?? server.defaultHost),
                                                   server: server,
                                                   sessionManager: sessionManager,
                                                   to: client,
                                                   hasPreviouslyWrittenHeaders: &sentResponseHead,
                                                   signalRequestResponseEvent: signalRequestResponseEvent)
                                } catch {
                                    killConnection = true
                                }
                            }
                            
                        }
                        
                        guard client.isConnected else {
                            return false
                        }
                        
                        if !killConnection && !hoppingQueue {
                            // Try and ready anything left in the request body so we can move on to
                            // any next request within the same connection
                            if bodyInputStream.chunked && bodyInputStream.lastChunkSize != 0 {
                                do {
                                    // Try getting next chunked. to ensure
                                    // lastChunkSize should be populated
                                    try bodyInputStream.readChunk()
                                    // Make sure lastChunkSize is populated or something
                                    // went wrong
                                    if bodyInputStream.lastChunkSize != nil {
                                        // Read each chunk until we get the 0 chunk
                                        while bodyInputStream.lastChunkSize != 0 {
                                            try bodyInputStream.readChunk()
                                        }
                                    } else {
                                        // Failed to get to end of chunks
                                        killConnection = true
                                    }
                                } catch {
                                    // Failed to get to end of chunks
                                    killConnection = true
                                }
                                
                            } else if let ctl = contentLength, // We can only do this if the header gave us a total body content length
                               (ctl - bodyInputStream.actualByteRead) > 0 { // Make sure we haven't read the whole body
                                
                                var remainingBodyToRead = ctl - bodyInputStream.actualByteRead
                                var tempBody = Array<UInt8>(repeating: 0, count: 10)
                                
                                while remainingBodyToRead > 0 {
                                    var requestingReadSize = tempBody.count
                                    if remainingBodyToRead < tempBody.count {
                                        requestingReadSize = Int(remainingBodyToRead)
                                    }
                                    do {
                                        let ret = try client.readBuffer(into: &tempBody, count: requestingReadSize)
                                        if ret == 0 { break }
                                        remainingBodyToRead -= ret
                                        
                                    } catch {
                                        killConnection = true
                                        break
                                    }
                                }
                            }
                        }
                        
                        if killConnection {
                            client.close()
                            keepAlive = false
                            return false
                        } else {
                            // Must read last \r\n of request?
                            /*
                            if ((request?.contentLength ?? 0) > 0) || (request?.isChunked ?? false) {
                                let _ = try? client.read(exactly: 2)
                            }
                            */
                        }
                        
                        return true
                    }
                    
                    
                    if !canContinue {
                        return
                    }
                    
                    firstRequest = false
                    requestCount += 1
                }
            }
        }
    }
}
