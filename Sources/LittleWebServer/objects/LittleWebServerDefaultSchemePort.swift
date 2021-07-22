//
//  LittleWebServerDefaultSchemePort.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-07-19.
//

import Foundation

/// Default Scheme/Port combinations
public struct LittleWebServerDefaultSchemePort {
    public let scheme: String
    public let secureScheme: String?
    public let isSecure: Bool
    public let port: UInt16
    
    public init(secureScheme scheme: String,
                port: UInt16) {
        self.scheme = scheme
        self.secureScheme = nil
        self.isSecure = true
        self.port = port
    }
    
    public init(scheme: String,
                port: UInt16,
                secureScheme: String? = nil) {
        self.scheme = scheme
        self.secureScheme = secureScheme
        self.isSecure = false
        self.port = port
    }
    /// Scheme/Port for HTTP protocol
    public static var http: LittleWebServerDefaultSchemePort {
        return LittleWebServerDefaultSchemePort(scheme: "http",
                                                port: 80,
                                                secureScheme: "https")
    }
    /// Scheme/Port for HTTPS protocol
    public static var https: LittleWebServerDefaultSchemePort {
        return LittleWebServerDefaultSchemePort(secureScheme: "https",
                                                port: 443)
    }
    /// Scheme/Port for WS protocol
    public static var ws: LittleWebServerDefaultSchemePort {
        return LittleWebServerDefaultSchemePort(scheme: "ws",
                                                port: 80,
                                                secureScheme: "wss")
    }
    /// Scheme/Port for WSS protocol
    public static var wss: LittleWebServerDefaultSchemePort {
        return LittleWebServerDefaultSchemePort(secureScheme: "wss",
                                                port: 443)
    }
    
    /// Scheme/Port for FTP Data protocol
    public static var ftpData: LittleWebServerDefaultSchemePort {
        return LittleWebServerDefaultSchemePort(scheme: "ftpd",
                                                port: 20)
    }
    
    /// Scheme/Port for FTP control protocol
    public static var ftp: LittleWebServerDefaultSchemePort {
        return LittleWebServerDefaultSchemePort(scheme: "ftp",
                                                port: 20,
                                                secureScheme: "sftp")
    }
    
    /// Scheme/Port for SFTP protocol
    public static var sftp: LittleWebServerDefaultSchemePort {
        return LittleWebServerDefaultSchemePort(secureScheme: "sftp",
                                                port: 115)
    }
    
    /// Scheme/Port for SSH protocol
    public static var ssh: LittleWebServerDefaultSchemePort {
        return LittleWebServerDefaultSchemePort(secureScheme: "ssh",
                                                port: 22)
    }
    
    /// Scheme/Port for Telnet protocol
    public static var telnet: LittleWebServerDefaultSchemePort {
        return LittleWebServerDefaultSchemePort(scheme: "telnet",
                                                port: 23)
    }
    
    /// Scheme/Port for SMTP protocol
    public static var smtp: LittleWebServerDefaultSchemePort {
        return LittleWebServerDefaultSchemePort(scheme: "smtp",
                                                port: 25)
    }
    
    /// A list of currently known scheme/ports
    public static var knownSchemePorts: [LittleWebServerDefaultSchemePort] {
        return [.http, .https, .ws, .wss, .ssh, .telnet, .smtp]
    }
    
    /// Tries to find the default details for the given scheme
    /// - Parameter scheme: The scheme to find the default details for
    /// - Returns: The default details if available
    public static func `default`(for scheme: String) -> LittleWebServerDefaultSchemePort? {
        let lowerScheme = scheme.lowercased()
        return self.knownSchemePorts.first(where: { return $0.scheme.lowercased() == lowerScheme })
    }
    
    /// Tries to find the default details for the given port
    /// - Parameter port: The port to find the default details for
    /// - Returns: The default details if available
    public static func `default`(for port: UInt16) -> LittleWebServerDefaultSchemePort? {
        return self.knownSchemePorts.first(where: { return $0.port == port })
    }
    
    /// Tries to find the default details for the given port
    /// - Parameter port: The port to find the default details for
    /// - Returns: The default details if available
    public static func `default`(for port: LittleWebServerSocketConnection.Address.TCPIPPort) -> LittleWebServerDefaultSchemePort? {
        return self.knownSchemePorts.first(where: { return $0.port == port.rawValue })
    }
    
    
}
