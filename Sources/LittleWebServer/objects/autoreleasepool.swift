//
//  autoreleasepool.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-02.
//

import Foundation

#if !_runtime(_ObjC)
internal func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result {
    return try body()
}
#endif
