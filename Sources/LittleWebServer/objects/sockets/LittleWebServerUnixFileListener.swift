//
//  LittleWebServerUnixFileListener.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-17.
//

import Foundation

/// A Unix File Listener
public class LittleWebServerUnixFileListener: LittleWebServerSocketListener {
    
    public let filePath: String
    
    public override var uid: String {
        return "\(self.scheme)://" + self.filePath
    }
    
    public init(path: String) throws {
        self.filePath = path
        let address = try Address("unix://" + path)
        
        try super.init(address: address, scheme: "unix")
    }
    
    open override func accept() throws -> LittleWebServerClient {
        let connectionDetails = try self.acceptSocket()
        return try LittleWebServerUnixFileClient(connectionDetails.socket,
                                                 address: connectionDetails.address,
                                                 scheme: self.scheme)
    }
}
