//
//  LittleWebServerConnection.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-17.
//

import Foundation
#if swift(>=5.4)
/// Protocol defining any connection
public protocol LittleWebServerConnection: AnyObject {
    /// The unique ID of  the given connection
    var uid: String { get }
    /// Indicator if the given connection is connected
    var isConnected: Bool { get }
    /// Closed the given connection
    func close()
}
#else
/// Protocol defining any connection
public protocol LittleWebServerConnection: class {
    /// The unique ID of  the given connection
    var uid: String { get }
    /// Indicator if the given connection is connected
    var isConnected: Bool { get }
    /// Closed the given connection
    func close()
}
#endif
