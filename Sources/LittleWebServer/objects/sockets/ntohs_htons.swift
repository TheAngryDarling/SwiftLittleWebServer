//
//  ntohs_htons.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-26.
//

import Foundation

#if !os(Linux)
private let isLittleEndian: Bool = Int(littleEndian: 42) == 42
internal func ntohs(_ port: in_port_t) -> in_port_t {
    if isLittleEndian {
        return port.byteSwapped
    } else {
        return port
    }
}
internal func htons(_ port: in_port_t) -> in_port_t {
    if isLittleEndian {
        return port.byteSwapped
    } else {
        return port
    }
}

#endif
