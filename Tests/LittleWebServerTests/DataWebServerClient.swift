//
//  DataWebServerClient.swift
//  LittleWebServerTests
//
//  Created by Tyler Anger on 2021-06-01.
//

import Foundation
@testable import LittleWebServer

class DataWebServerClient: LittleWebServerClient {
    public struct _LittleWebServerClientDetails: LittleWebServerClientDetails {
        public let uid: String
        public let uuid: UUID
        public let scheme: String
        
        public init() {
            self.uuid = UUID()
            self.uid = self.uuid.uuidString
            self.scheme = "TEST"
        }
    }
    
    var connectionDetails: LittleWebServerClientDetails = _LittleWebServerClientDetails()
    
    
    
    private var readData: Data
    public var currentReadIndex = 0
    
    private var deallocData: Bool
    
    public var writeData: Data = Data()
    //public let uid: String = UUID().uuidString
    
    public let isConnected: Bool = true
    
    public init(_ readData: Data) {
        
        self.readData =  readData
        self.deallocData = true
    }
    public convenience init(requests: [LittleWebServer.HTTP.Request]) {
        var data = Data()
        for request in requests {
            data.append(request.rawValue)
        }
        
        self.init(data)
    }
    public convenience init(_ requests: LittleWebServer.HTTP.Request...) {
        self.init(requests: requests)
    }
    public convenience init?(_ string: String) {
        guard let dta = string.data(using: .utf8) else {
            return nil
        }
        self.init(dta)
    }
    
    deinit {
        self.readData.removeAll()
        self.writeData.removeAll()
    }
    
    func close() {
        // Do nothing
    }
    
    func readBuffer(into buffer: UnsafeMutablePointer<UInt8>, count: Int) throws -> UInt {
        var read: Int = count
        if count > (self.readData.count - self.currentReadIndex) {
            read = (self.readData.count - self.currentReadIndex)
        }
        guard read > 0 else { return 0 }
        
        for i in 0..<read {
            buffer[i] = self.readData[self.currentReadIndex + i]
        }
        
        self.currentReadIndex += read
        

        return UInt(read)
    }
    
    func writeBuffer(_ pointer: UnsafeRawPointer, length: Int) throws {
        
    }
}
