//
//  LittleWebServerIdentifiableObject.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-07-19.
//

import Foundation

public protocol LittleWebServerIdentifiableObject {
    associatedtype ID: Hashable
    
    var id: ID { get }
}
