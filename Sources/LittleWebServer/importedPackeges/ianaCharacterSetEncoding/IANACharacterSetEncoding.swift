//
//  IANACharacterSetEncoding.swift
//  
//
//  Created by Tyler Anger on 2022-09-05.
//

import Foundation
import CoreFoundation

fileprivate extension String {
    /// CFString version of the current string
    var cfString: CFString {
        let chars = Array(self.utf16)
        let cfStr = CFStringCreateWithCharacters(nil, chars, self.utf16.count)
        let str = CFStringCreateCopy(nil, cfStr)!
        return str
    }
}

fileprivate extension NSString {
    /// String version of the current NSString
    var string: String {
        return self.appending("") // Cheating way to support on all platforms
    }
}

fileprivate extension CFString {
    /// NSString version of the current CFString
    var nsString: NSString { return unsafeBitCast(self, to: NSString.self) }
    
    /// String version of the current CFString
    var string: String { return self.nsString.string }
}

internal extension String.Encoding {
    
    /// The IANA Character Set name for this encoding if one is available
    var IANACharSetName: String? {
        guard self.rawValue != 1 else { return "ascii" } //Standardize ASCII
        
        
        let se = CFStringConvertNSStringEncodingToEncoding(self.rawValue)
        let cfe =  CFStringConvertEncodingToIANACharSetName(se)
        //Convert CFString to NSString to String
        return cfe?.string
    }
    
    /// The IANA Character Set name for this encoding with dashes removed
    var noDashIANACharSetName: String? {
        return self.IANACharSetName?.replacingOccurrences(of: "-", with: "")
    }
    
    /// Create String.Encoding based in IANA Character Set or returns nil if name does not match an encoding
    ///
    /// - Parameter name: IANA Character Set Name
    init?(IANACharSetName name: String) {
        
        // https://stackoverflow.com/questions/44730379/how-can-i-convert-a-string-such-as-iso-8859-1-to-its-string-encoding-counte
        
        let cfe = CFStringConvertIANACharSetNameToEncoding(name.cfString)
        if cfe == kCFStringEncodingInvalidId { return nil }
        let se = CFStringConvertEncodingToNSStringEncoding(cfe)
        
        self.init(rawValue: se)
        
    }
}
