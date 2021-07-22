//
//  LittleWebServerSimilarOperator.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-07-11.
//

import Foundation

/// Defines an object that has the similar operator
public protocol LittleWebServerSimilarOperator {
    static func ~=(lhs: Self, rhs: Self) -> Bool
}
