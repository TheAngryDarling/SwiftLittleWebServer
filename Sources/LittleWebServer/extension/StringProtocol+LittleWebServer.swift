//
//  StringProtocol+LittleWebServer.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-06-19.
//

import Foundation

internal extension StringProtocol where Index == String.Index {
    func splitFirst(separator: Character, omittingEmptySubsequences: Bool = true) -> [Substring] {
        guard !self.isEmpty else { return [] }
        guard let r = self.range(of: "\(separator)") else {
            return [Substring(self)]
        }
        
        let first = self[self.startIndex..<r.lowerBound]
        let last = self[r.upperBound..<self.endIndex]
        
        var rtn: [Substring] = []
        if !omittingEmptySubsequences || (omittingEmptySubsequences && !first.isEmpty) {
            rtn.append(Substring(first))
        }
        if !omittingEmptySubsequences || (omittingEmptySubsequences && !last.isEmpty) {
            rtn.append(Substring(last))
        }
        
        return rtn
        
    }
}
