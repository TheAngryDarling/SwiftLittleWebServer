//
//  Request.swift
//  LittleWebServerTests
//
//  Created by Tyler Anger on 2021-06-01.
//

import Foundation
@testable import LittleWebServer
internal extension LittleWebServer.HTTP.Request {
    /// For Testing Purposes
    static func parse(from client: LittleWebServerClient,
                      bodyStream: _LittleWebServerInputStream,
                      uploadedFiles: inout  [LittleWebServer.HTTP.Request.UploadedFileReference],
                      tempLocation: URL = URL(fileURLWithPath: NSTemporaryDirectory())) throws -> LittleWebServer.HTTP.Request {
        let head = try client.readRequestHead()
        
        let headers = try client.readRequestHeaders()
        
        bodyStream.chunked = headers.transferEncodings.contains(.chunked)
        
        //let tempSessionManager = LittleWebServer.DefaultSessionManager()
        
        return try LittleWebServer.HTTP.Request.parse(scheme: "http",
                                                      head: head,
                                                      headers: headers,
                                                      bodyStream: bodyStream,
                                                      uploadedFiles: &uploadedFiles,
                                                      tempLocation: tempLocation)
    }
    
    static func parse(from client: LittleWebServerClient,
                      uploadedFiles: inout  [LittleWebServer.HTTP.Request.UploadedFileReference],
                      tempLocation: URL = URL(fileURLWithPath: NSTemporaryDirectory())) throws -> LittleWebServer.HTTP.Request {
        return try self.parse(from: client,
                              bodyStream: _LittleWebServerInputStream(client: client),
                              uploadedFiles: &uploadedFiles,
                              tempLocation: tempLocation)
    }
}
