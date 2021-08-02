//
//  Request.swift
//  LittleWebServerTests
//
//  Created by Tyler Anger on 2021-06-01.
//

import Foundation
@testable import LittleWebServer
internal extension LittleWebServer.HTTP.Request {
    
    static func parse(from client: LittleWebServerClient,
                      uploadedFiles: inout  [LittleWebServer.HTTP.Request.UploadedFileReference],
                      tempLocation: URL = URL(fileURLWithPath: NSTemporaryDirectory())) throws -> LittleWebServer.HTTP.Request {
        
        return try HTTPParserV1_1.parseRequest(scheme: "http",
                                               uploadedFiles: &uploadedFiles,
                                               tempLocation: tempLocation,
                                               from: client)
    }
 
}
