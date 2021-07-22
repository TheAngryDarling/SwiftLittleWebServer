//
//  RouteConditions.swift
//  LittleWebServer
//
//  Created by Tyler Anger on 2021-05-17.
//

import Foundation

/// Path Routing conditions
public struct LittleWebServerRoutePathConditions: LittleWebServerExpressibleByStringInterpolation,
                                   CustomStringConvertible,
                                   Equatable,
                                   Collection {
    
    public enum Error: Swift.Error {
        case invalidParameterConditionList(String, message: String)
        case invalidParmeterArray(String, message: String)
        case invalidParmeterTransformer(String, message: String)
        case invalidCharacterFound(String, character: Character, expecting: [Character])
        case extraCharactersInAnythingHereafterPath(String)
        case extraCharactersInAnythingPath(String)
        case invalidConditionContainer(String, expectedStart: Character, expectedEnd: Character, foundStart: Character, foundEnd: Character)
        
        case invalidObjectContainer(String, expectedStart: Character, expectedEnd: Character, foundStart: Character, foundEnd: Character, message: String?)
        
        
        case unableToParse(container: Parsing.BlockContainer, in: String, with: Range<String.Index>)
        case missingArraySeparator(container: Parsing.BlockContainer, separator: Character, in: String, expectedLocation: String.Index)
        
        
        case missingSeparator(separator: Character, in: String, expectedLocation: String.Index?, type: String, message: String?)
        
        case missingKeyValueSeparator(Character, in: String)
        case missingKeyPrefix(Character, in: String)
        case missingKeySuffix(Character, in: String)
        case foundEndOfRangeBeforeFinishedParsing
        case pathPatternAlreadyExists(current: PathComponentPattern, new: PathComponentPattern)
       
    
        case missingSuffix(String, suffix: String)
        
        case foundExtraTrailingString(String)
        
        case duplicateParameterKeyFound(String)
        
        case pathSliceMustNotStartWithPathSeparator
        case pathComponentCanNotBeAfterAnythingHereafter
        
       
    }
    
    public struct Parsing {
        private init() { }
    
    
        /// String block identifier by opening and closing characters
        public class BlockContainer {
            
            /// Details about the block in the string
            public struct BlockDetails {
                /// The range of the block including the opening and closing characters
                let outer: Range<String.Index>
                /// The range of the body of the block.  This can exclude any prefix or trailing spaces if block supports it
                let inner: Range<String.Index>
                
                // Gets the body string of the block providing the string the block was parsed from
                func innerValue(from string: String) -> String {
                    return String(string[self.inner])
                }
                // Gets the bock string providing the string the block was parsed from
                func outerValue(from string: String) -> String {
                    return String(string[self.outer])
                }
                
                /// Returs the rest of the string after the given block within the parsed string
                /// If parentContainer is provided this will trim any prefix spaces from the reutrning string of the parentContainer supports
                /// spaces
                func afterBlock(from string: String, parentContainer: BlockContainer? = nil) -> String {
                    var rtn = String(string[self.outer.upperBound..<string.endIndex])
                    let supportsSpaces = parentContainer?.supportsSpacing ?? false
                    while supportsSpaces && rtn.first == " " {
                        rtn.removeFirst()
                    }
                    return rtn
                }
            }
            
            /// The opening character of the block
            public let opener: Character
            /// The closing character of the block
            public let closure: Character
            /// Indicator if the block supports spacing between content objects
            /// This allows for spacing after the opening block and spacing before closing block
            /// as well as spacing between any child objects on inherited Block Containers
            public let supportsSpacing: Bool
            
            /// The output for the opener of the block
            /// If supportsSpacing is enabled this will
            /// add a space after the opener character
            public var outputOpener: String {
                var rtn: String = "\(self.opener)"
                if self.supportsSpacing { rtn += " "}
                return rtn
            }
            
            /// The output for the closing of the block
            /// If supportsSpacing is enabled this will
            /// add a space before the closing character
            public var outputClosure: String {
                var rtn: String = ""
                if self.supportsSpacing { rtn += " "}
                rtn += "\(self.closure)"
                return rtn
            }

            
            
            /// Create a new block container
            /// - Parameters:
            ///   - opener: The opening character indicator
            ///   - closure: The closing character indicator
            ///   - supportsSpacing: Indicator if this block supports spacing between opener/closure indicators and the inner properties
            public init(opener: Character,
                        closure: Character,
                        supportsSpacing: Bool = true) {
                self.opener = opener
                self.closure = closure
                self.supportsSpacing = supportsSpacing
            }
            
            /// Wrap the body in the block closure
            public func make(_ body: String) -> String {
                return self.outputOpener + body + self.outputClosure
            }
            
            /// Parse the closure from the string within the given range
            public func parse(from string: String, in range: Range<String.Index>) -> BlockDetails? {
                // ensure the first character within the range is the opener character
                guard string[range.lowerBound] == self.opener else { return nil }
                
                var startIndex: String.Index = string.index(after: range.lowerBound)
                
                // trim leaning spaces
                while self.supportsSpacing &&
                      startIndex < range.upperBound &&
                      string[startIndex] == " " {
                    startIndex = string.index(after: startIndex)
                }
                // make sure we haven't went to the end of the range
                // otherwise we failed to parse the details since we
                // didn't find the closing character
                guard startIndex < range.upperBound else { return nil }
                
                
                var currentIndex: String.Index = startIndex
                var endIndex: String.Index? = nil
                
                var innerClosureCount: Int = 0
                // Loop through to find the matching closing character
                // acconting for any inner blocks
                while endIndex == nil && currentIndex < range.upperBound {
                    if string[currentIndex] == self.closure {
                        if innerClosureCount == 0 {
                            // We found the closing character of the block
                            endIndex = currentIndex
                        } else {
                            // We just exited an inner block
                            innerClosureCount -= 1
                        }
                        // There were too many inner closing characters
                        if innerClosureCount < 0 { return nil }
                    } else if string[currentIndex] == self.opener {
                        // We found the opening character of an inner block
                        innerClosureCount += 1
                    }
                    // Go to next character
                    currentIndex = string.index(after: currentIndex)
                }
                
                // Make sure we found the closing character
                guard var e = endIndex else { return nil }
                
                // Trim any spacing from body before
                // closing character
                while self.supportsSpacing &&
                      e > startIndex &&
                      string[string.index(before: e)] == " " {
                    e = string.index(before: e)
                }
                
                // Make sure end of body index is not before
                // start of body index
                guard startIndex <= e else { return nil }

                return BlockDetails(outer: range.lowerBound..<string.index(after: endIndex!),
                        
                                      inner: startIndex..<e)
            }
            
            /// Parse the closure from the string.  Optional start index to indicate where to start looking
            /// Otherwise start at beginning of string
            public func parse(from string: String, startingAt index: String.Index? = nil) -> BlockDetails? {
                let idx: String.Index = index ?? string.startIndex
                return self.parse(from: string, in: idx..<string.endIndex)
            }
        }
        
        /// String array block identifier by opening, closing, and separator characters
        public class ArrayContainer: BlockContainer {
            /// Details about the array
            public struct ArrayClosureDetails<Element> {
                let outer: Range<String.Index>
                let inner: Range<String.Index>
                let elements: [Element]
                
                /// Create a new ArrayClosureDetails
                /// - Parameters:
                ///   - outer: The full range of the closure including the opening and closing indicators
                ///   - inner: The inner range of the closure.  This excludes the opening and closing indicators. and may excludes any leading/trailing spaces if the Block hand supportsSpacing enabled
                ///   - elements: The element blocks
                public init(outer: Range<String.Index>,
                            inner: Range<String.Index>,
                            elements: [Element]) {
                    self.outer = outer
                    self.inner = inner
                    self.elements = elements
                }
                
                /// Create a new ArrayClosureDetails
                /// - Parameters:
                ///   - base: The element block details
                ///   - elements: The element blocks
                public init(_ base: BlockDetails, elements: [Element]) {
                    self.init(outer: base.outer,
                              inner: base.inner,
                              elements: elements)
                }
            }
            
            /// The character separator of the array
            public let separator: Character
            
            /// The output for the separator of the
            /// elements in the block.
            /// If supportsSpacing is enabled this will
            /// add a space before and after separator character
            public var outputSeparator: String {
                var rtn: String = "\(self.separator)"
                if self.supportsSpacing { rtn = " " + rtn + " " }
                return rtn
            }
            
            /// Create a new Array Block
            /// - Parameters:
            ///   - opener: The opening character indicator
            ///   - closure: The closing character indicator
            ///   - separator: The element separator character
            ///   - supportsSpacing: Indicator if this block supports spacing between elements
            fileprivate init(opener: Character,
                             closure: Character,
                             separator: Character,
                             supportsSpacing: Bool) {
                self.separator = separator
                super.init(opener: opener, closure: closure, supportsSpacing: supportsSpacing)
                
            }
            /// Creates a new Array Block with [ as opener and ] as closure
            /// - Parameters:
            ///   - separator: The element separator character
            ///   - supportsSpacing: Indicator if this block supports spacing between elements
            public convenience init(separator: Character = ",", supportsSpacing: Bool = true) {
                self.init(opener: "[",
                          closure: "]",
                          separator: separator,
                          supportsSpacing: true)
            }
            
            /// Wrap the elements in the block closure separated by the separator character
            /// if the elementContainer parameter is provided, will call elementContainer.make on each element
            /// before adding to the returning string
            public func make(_ elements: [String], with elementContainer: BlockContainer? = nil) -> String {
                guard elements.count > 0 else {
                    return self.outputOpener + "\(self.closure)"
                }
                
                var rtn = self.outputOpener
                let sep = self.outputSeparator
                for (index, element) in elements.enumerated() {
                    if index > 0 { rtn += sep }
                    rtn += elementContainer?.make(element) ?? element
                }
                
                rtn += self.outputClosure
                return rtn
                
            }
            
            /// Parse block details of each element in the array
            /// - Parameters:
            ///   - elementContainer: The container for the element
            ///   - string: The string thats being parsed
            ///   - range: The range within the string that we are paring
            ///   - isLiteralInit: If this parsing is called within a stringLIteral init (If true, any errors will be executed as preconditionFailures)
            ///   - onElement: The tranformer to call on each element block found
            /// - Returns: Returns the ArrayClosureDetails containing the inner and outer ranges of the array as well as an array of elements from the reutrn of the onElement tranformer
            public func parseElements<Element>(elementContainer: BlockContainer,
                                      from string: String,
                                      in range: Range<String.Index>,
                                      isLiteralInit: Bool = false,
                                      onElement: (BlockContainer.BlockDetails) throws -> Element) throws -> ArrayClosureDetails<Element>? {
                
                guard let baseDetails = self.parse(from: string, in: range) else { return nil }
                
                guard !baseDetails.inner.isEmpty else { return ArrayClosureDetails(baseDetails, elements: [])  }
                
                var elements: [Element] = []
                
                
                var workingStartIndex = baseDetails.inner.lowerBound
                while workingStartIndex < baseDetails.inner.upperBound {
                    guard let element = elementContainer.parse(from: string,
                                                               in: workingStartIndex..<baseDetails.inner.upperBound) else {
                        if isLiteralInit {
                            preconditionFailure("Unable to parse container '\(elementContainer.opener)'-'\(elementContainer.closure)' in substring '\(string[workingStartIndex..<baseDetails.inner.upperBound])' ")
                        } else {
                            throw Error.unableToParse(container: elementContainer,
                                                                     in: string,
                                                                     with: workingStartIndex..<baseDetails.inner.upperBound)
                        }
                    }
                    let e = try onElement(element)
                    elements.append(e)
                    
                    workingStartIndex = element.outer.upperBound
                    
                    // Stored for later if we can't find separator we will pass this to error
                    let expectedSeparatorLocation: String.Index = workingStartIndex
                    // filter out spaces
                    while string[workingStartIndex] == " " && workingStartIndex < baseDetails.inner.upperBound  {
                        workingStartIndex = string.index(after: workingStartIndex)
                    }
                    
                    if workingStartIndex < baseDetails.inner.upperBound {
                        guard string[workingStartIndex] == self.separator else {
                            if isLiteralInit {
                                preconditionFailure("Missing array separator '\(self.separator)' in string.  Expected at \(string.distance(from: string.startIndex, to: expectedSeparatorLocation)), found '\(string[workingStartIndex] )'")
                            } else {
                                throw Error.missingSeparator(separator: self.separator,
                                                                            in: String(string[element.outer.lowerBound..<baseDetails.inner.upperBound]),
                                                                            expectedLocation: expectedSeparatorLocation,
                                                                            type: "element",
                                                                            message: "Missing element separator")
                            }
                        }
                        
                        workingStartIndex = string.index(after: workingStartIndex)
                        // filter out spaces
                        while string[workingStartIndex] == " " && workingStartIndex < baseDetails.inner.upperBound  {
                            workingStartIndex = string.index(after: workingStartIndex)
                        }
                        
                    }
                    
                }
                
                
                
                return ArrayClosureDetails(baseDetails, elements: elements)
            }
            
            /// Parse block details of each element in the array
            /// - Parameters:
            ///   - elementContainer: The container for the element
            ///   - string: The string thats being parsed
            ///   - index: The starting index of where the parser should start looking, (If nil this will be the start of the string)
            ///   - isLiteralInit: If this parsing is called within a stringLIteral init (If true, any errors will be executed as preconditionFailures)
            ///   - onElement: The tranformer to call on each element block found
            /// - Returns: Returns the ArrayClosureDetails containing the inner and outer ranges of the array as well as an array of elements from the reutrn of the onElement tranformer
            public func parseElements<Element>(elementContainer: BlockContainer,
                                      from string: String,
                                      startingAt index: String.Index? = nil,
                                      isLiteralInit: Bool = false,
                                      onElement: (BlockContainer.BlockDetails) throws -> Element) throws -> ArrayClosureDetails<Element>? {
                let start = index ?? string.startIndex
                
                return try self.parseElements(elementContainer: elementContainer,
                                              from: string,
                                              in: start..<string.endIndex,
                                              isLiteralInit: isLiteralInit,
                                              onElement: onElement)
            }
            
            /// Parse the string of each element in the array
            /// - Parameters:
            ///   - elementContainer: The container for the element
            ///   - string: The string thats being parsed
            ///   - range: The range within the string that we are paring
            ///   - isLiteralInit: If this parsing is called within a stringLIteral init (If true, any errors will be executed as preconditionFailures)
            ///   - onElement: The tranformer to call on each element block found
            /// - Returns: Returns the ArrayClosureDetails containing the inner and outer ranges of the array as well as an array of elements from the reutrn of the onElement tranformer
            public func parseFromStringElements<Element>(elementContainer: BlockContainer,
                                                     from string: String,
                                                     in range: Range<String.Index>,
                                                     isLiteralInit: Bool = false,
                                                     onElement: (String) throws -> Element) throws -> ArrayClosureDetails<Element>? {
                
                return try self.parseElements(elementContainer: elementContainer,
                                              from: string,
                                              in: range,
                                              isLiteralInit: isLiteralInit) { b throws -> Element in
                    return try onElement(String(string[b.inner]))
                }
                
            }
            
            /// Parse the string of each element in the array
            /// - Parameters:
            ///   - elementContainer: The container for the element
            ///   - string: The string thats being parsed
            ///   - index: The starting index of where the parser should start looking, (If nil this will be the start of the string)
            ///   - isLiteralInit: If this parsing is called within a stringLIteral init (If true, any errors will be executed as preconditionFailures)
            ///   - onElement: The tranformer to call on each element block found
            /// - Returns: Returns the ArrayClosureDetails containing the inner and outer ranges of the array as well as an array of elements from the reutrn of the onElement tranformer
            public func parseFromStringElements<Element>(elementContainer: BlockContainer,
                                                     from string: String,
                                                     startingAt index: String.Index? = nil,
                                                     isLiteralInit: Bool = false,
                                                     onElement: (String) throws -> Element) throws -> ArrayClosureDetails<Element>? {
                
                let start = index ?? string.startIndex
                
                return try self.parseFromStringElements(elementContainer: elementContainer,
                                                        from: string,
                                                        in: start..<string.endIndex,
                                                        isLiteralInit: isLiteralInit,
                                                        onElement: onElement)
            }
        }
        
        /// String dictionary block identifier by opening, closing, key/value separator, and element separator characters
        public class DictionaryContainer: BlockContainer {
            
            /// Details of the key/value element
            public struct KeyValueElementDetails {
                let complete: Range<String.Index>
                let key: Range<String.Index>
                let value: BlockDetails
            }
            /// Details about the dictionary
            public typealias DictionaryClosureDetils<Element> = ArrayContainer.ArrayClosureDetails<Element>
            
            /// The character key prefix of the key element
            public let keyPrefix: Character
            /// The character key suffix of the key element
            public let keySuffix: Character?
            /// The character key/value separator
            public let keyValueSeparator: Character
            /// The output for the key/value sepatator
            /// If supportsSpacing is enabled this will
            /// add a space before and after the key/value sepatator character
            public var outputKeyValueSeparator: String {
                var rtn: String = "\(self.keyValueSeparator)"
                if self.supportsSpacing { rtn = " " + rtn + " " }
                return rtn
            }
            
            /// The character element separator
            public let elementSeparator: Character
            /// The output for the element sepatator
            /// If supportsSpacing is enabled this will
            /// add a space before and after the element sepatator character
            public var outputElementSeparator: String {
                var rtn: String = "\(self.elementSeparator)"
                if self.supportsSpacing { rtn = " " + rtn + " " }
                return rtn
            }
            
            
            
            /// Create new Dictionary Block
            /// - Parameters:
            ///   - keyPrefix: The dictionary Key prefix
            ///   - keySuffix: The dictionary Key suffix (if one is used)
            ///   - keyValueSeparator: The Key/Value separator (Default: :)
            ///   - elementSeparator: The element separator (Default: ,)
            ///   - supportsSpacing: Indicator if this block supports spacing between elements
            public init(keyPrefix: Character = "@",
                        keySuffix: Character? = nil,
                        keyValueSeparator: Character = ":",
                        elementSeparator: Character = ",",
                        supportsSpacing: Bool = true) {
                self.keyPrefix = keyPrefix
                self.keySuffix = keySuffix
                self.keyValueSeparator = keyValueSeparator
                self.elementSeparator = elementSeparator
                
                super.init(opener: "{",
                           closure: "}",
                           supportsSpacing: supportsSpacing)
            }
            
            /// Wrap the key/value elements in the block closure separated by the element separator character
            /// if the valueContainer parameter is provided, will call valueContainer.make on each value
            /// before adding to the returning string
            public func make(_ elements: [String: String], with valueContainer: BlockContainer? = nil) -> String {
                guard elements.count > 0 else {
                    return self.outputOpener + "\(self.closure)"
                }
                
                var rtn = self.outputOpener
                let sep = self.outputElementSeparator
                let keyValSep = self.outputKeyValueSeparator
                for (index, key) in elements.keys.sorted().enumerated() {
                    if index > 0 { rtn += sep }
                    rtn += "\(self.keyPrefix)"
                    rtn += key
                    if let s = self.keySuffix {
                        rtn += "\(s)"
                    }
                    rtn += keyValSep
                    let val = elements[key]!
                    rtn += valueContainer?.make(val) ?? val
                }
                
                rtn += self.outputClosure
                return rtn
            }
            
            /// Parse block details of each element in the array
            /// - Parameters:
            ///   - valueContainer: The container for the value object
            ///   - string: The string thats being parsed
            ///   - range: The range within the string that we are paring
            ///   - isLiteralInit: If this parsing is called within a stringLIteral init (If true, any errors will be executed as preconditionFailures)
            ///   - onElement: The tranformer to call on each key/value block found
            /// - Returns: Returns the DictionaryClosureDetils containing the inner and outer ranges of the dictionary as well as an array of elements from the reutrn of the onElement tranformer
            public func parseElements<Element>(valueContainer: BlockContainer,
                                               from string: String,
                                               in range: Range<String.Index>,
                                               isLiteralInit: Bool = false,
                                               onElement: (KeyValueElementDetails) throws -> Element) throws -> DictionaryClosureDetils<Element>? {
                
                guard let baseDetails = self.parse(from: string, in: range) else { return nil }
                
                
                guard !baseDetails.inner.isEmpty else { return DictionaryClosureDetils(baseDetails, elements: [])  }
                
                var elements: [Element] = []
                
                var workingStartIndex = baseDetails.inner.lowerBound
                while workingStartIndex < baseDetails.inner.upperBound {
                    let startLock = workingStartIndex
                    var keyStartIndex = workingStartIndex
                    guard string[keyStartIndex] == self.keyPrefix else {
                        if isLiteralInit {
                            preconditionFailure("Missing key prefix '\(self.keyPrefix)' in string starting at '\(string[keyStartIndex..<baseDetails.inner.upperBound])'.")
                        } else {
                            throw Error.missingKeyPrefix(self.keyPrefix,
                                                                        in: String(string[keyStartIndex..<baseDetails.inner.upperBound]))
                        }
                    }
                    keyStartIndex = string.index(after: keyStartIndex)
                    
                    
                    guard let separatorRange = string.range(of: self.keyValueSeparator,
                                                            range: keyStartIndex..<baseDetails.inner.upperBound) else {
                        if isLiteralInit {
                            preconditionFailure("Missing key/value separator '\(self.keyValueSeparator)' in string '\(string[keyStartIndex..<baseDetails.inner.upperBound])'.")
                        } else {
                            throw Error.missingSeparator(separator: self.keyValueSeparator,
                                                                        in: String(string[keyStartIndex..<baseDetails.inner.upperBound]),
                                                                        expectedLocation: nil,
                                                                        type: "key/value",
                                                                        message: "Missing Key/Value separator")
                            
                        }
                    }
                    
                    var keyEndIndex = separatorRange.lowerBound
                    if self.supportsSpacing {
                        while string[string.index(before: keyEndIndex)] == " " {
                            keyEndIndex = string.index(before: keyEndIndex)
                        }
                    }
                    
                    if let s = self.keySuffix {
                        guard string[keyEndIndex] == s else {
                            if isLiteralInit {
                                preconditionFailure("Missing key suffix '\(s)' in string starting at '\(string[keyEndIndex..<baseDetails.inner.upperBound])'.")
                            } else {
                                throw Error.missingKeySuffix(s,
                                                                            in: String(string[keyEndIndex..<baseDetails.inner.upperBound]))
                            }
                        }
                        keyEndIndex = string.index(before: keyStartIndex)
                    }
                    
                    var valueStartIndex = separatorRange.upperBound
                    if self.supportsSpacing {
                        while valueStartIndex < baseDetails.inner.upperBound &&
                            string[valueStartIndex] == " " {
                            valueStartIndex = string.index(after: valueStartIndex)
                        }
                        guard valueStartIndex < baseDetails.inner.upperBound else {
                            if isLiteralInit {
                                preconditionFailure("Found end of range before finished parsing")
                            } else {
                                throw Error.foundEndOfRangeBeforeFinishedParsing
                            }
                        
                        }
                    }
                    
                    guard string[valueStartIndex] == valueContainer.opener else {
                        let foundCharacter = string[valueStartIndex]
                        if isLiteralInit {
                            preconditionFailure("Invalid character found in 'string[valueStartIndex..<baseDetails.inner.upperBound]'.  Expected '\(valueContainer.opener)' but found '\(foundCharacter)'")
                        } else {
                            throw Error.invalidCharacterFound(String(string[valueStartIndex..<baseDetails.inner.upperBound]),
                                                                             character: foundCharacter,
                                                                             expecting: [valueContainer.opener])
                        }
                        
                        
                    }
                    
                    guard let valueContainerDetails = valueContainer.parse(from: string,
                                                                      in: valueStartIndex..<baseDetails.inner.upperBound) else {
                        
                        if isLiteralInit {
                            preconditionFailure("Unable to parse '\(string[valueStartIndex..<baseDetails.inner.upperBound])' with container \(valueContainer)")
                        } else {
                            throw Error.unableToParse(container: valueContainer,
                                                                     in: string,
                                                                     with: valueStartIndex..<baseDetails.inner.upperBound)

                        }
                    }
                    
                    
                    //print("Base: '\(string[baseDetails.inner])'")
                    //print("Value.outer: '\(string[valueContainerDetails.outer])'")
                    //print("Value.inner: '\(string[valueContainerDetails.inner])'")
                    
                    
                    
                    
                    // move workingStartIndex to after the current value
                    workingStartIndex = valueContainerDetails.outer.upperBound
                    // remove any white space
                    while workingStartIndex < baseDetails.inner.upperBound &&
                          string[workingStartIndex] == " " {
                        workingStartIndex = string.index(after: workingStartIndex)
                    }
                    
                    if workingStartIndex < baseDetails.inner.upperBound {
                        guard  string[workingStartIndex] == self.elementSeparator else {
                            if isLiteralInit {
                                preconditionFailure("Missing element separator '\(self.elementSeparator)' in string.  Expected at \(string.distance(from: string.startIndex, to: workingStartIndex))")
                            } else {
                                throw Error.missingSeparator(separator: self.elementSeparator,
                                                                            in: String(string[workingStartIndex..<baseDetails.inner.upperBound]),
                                                                            expectedLocation: workingStartIndex,
                                                                            type: "element",
                                                                            message: "Missing element separator")
                            }
                        }
                        // move past element separator
                        workingStartIndex = string.index(after: workingStartIndex)
                        // remove any white space
                        while workingStartIndex < baseDetails.inner.upperBound &&
                              string[workingStartIndex] == " " {
                            workingStartIndex = string.index(after: workingStartIndex)
                        }
                    }
                    
                    let e = try onElement(KeyValueElementDetails(complete: startLock..<valueContainerDetails.outer.upperBound,
                                                                 key: keyStartIndex..<keyEndIndex,
                                                                 value: valueContainerDetails))
                    
                    elements.append(e)
                    
                }
                
                return DictionaryClosureDetils(baseDetails, elements: elements)
                
                
                
                
                
            }
            
            /// Parse block details of each element in the array
            /// - Parameters:
            ///   - valueContainer: The container for the value object
            ///   - string: The string thats being parsed
            ///   - index: The index in the string where to start searching, (If nil will start at start of string)
            ///   - isLiteralInit: If this parsing is called within a stringLIteral init (If true, any errors will be executed as preconditionFailures)
            ///   - onElement: The tranformer to call on each key/value block found
            /// - Returns: Returns the DictionaryClosureDetils containing the inner and outer ranges of the dictionary as well as an array of elements from the reutrn of the onElement tranformer
            public func parseElements<Element>(valueContainer: BlockContainer,
                                               from string: String,
                                               startingAt index: String.Index? = nil,
                                               isLiteralInit: Bool = false,
                                               onElement: (KeyValueElementDetails) throws -> Element) throws -> DictionaryClosureDetils<Element>? {
                let start = index ?? string.startIndex
                return try self.parseElements(valueContainer: valueContainer,
                                              from: string,
                                              in: start..<string.endIndex,
                                              isLiteralInit: isLiteralInit,
                                              onElement: onElement)
            }
            /// Parse the string of each element in the array
            /// - Parameters:
            ///   - valueContainer: The container for the value
            ///   - string: The string thats being parsed
            ///   - range: The range within the string that we are paring
            ///   - isLiteralInit: If this parsing is called within a stringLIteral init (If true, any errors will be executed as preconditionFailures)
            ///   - onElement: The tranformer to call on each element block found
            /// - Returns: Returns the DictionaryClosureDetils containing the inner and outer ranges of the dictionary as well as an array of elements from the reutrn of the onElement tranformer
            public func parseFromStringElements<Element>(valueContainer: BlockContainer,
                                                         from string: String,
                                                         in range: Range<String.Index>,
                                                         isLiteralInit: Bool = false,
                                                         onElement: (String, String) throws -> Element) throws -> DictionaryClosureDetils<Element>? {
                return try self.parseElements(valueContainer: valueContainer,
                                              from: string,
                                              in: range,
                                              isLiteralInit: isLiteralInit) { e throws -> Element in
                    
                    let key = String(string[e.key])
                    let val = String(string[e.value.inner])
                    //print("{key: '\(key)', value: '\(val)'}")
                    return try onElement(key, val)
                }
            }
            
            /// Parse the string of each element in the array
            /// - Parameters:
            ///   - valueContainer: The container for the value
            ///   - string: The string thats being parsed
            ///   - index: The index in the string where to start searching, (If nil will start at start of string)
            ///   - isLiteralInit: If this parsing is called within a stringLIteral init (If true, any errors will be executed as preconditionFailures)
            ///   - onElement: The tranformer to call on each element block found
            /// - Returns: Returns the DictionaryClosureDetils containing the inner and outer ranges of the dictionary as well as an array of elements from the reutrn of the onElement tranformer
            public func parseFromStringElements<Element>(valueContainer: BlockContainer,
                                               from string: String,
                                               startingAt index: String.Index? = nil,
                                               isLiteralInit: Bool,
                                               onElement: (String, String) throws -> Element) throws -> DictionaryClosureDetils<Element>? {
                let start = index ?? string.startIndex
                return try self.parseFromStringElements(valueContainer: valueContainer,
                                                        from: string,
                                                        in: start..<string.endIndex,
                                                        isLiteralInit: isLiteralInit,
                                                        onElement: onElement)
            }
            
        }
        
        /// Container for any standard object
        public static let objectContainer: BlockContainer = .init(opener: "{",
                                                                     closure: "}")
        /// Container for any Array object
        public static let arrayContainer: ArrayContainer = .init(supportsSpacing: true)
       
        /// Container for any Dictionary
        public static let dictionaryContainer: DictionaryContainer = .init(keyPrefix: "@",
                                                                           keySuffix: nil,
                                                                           keyValueSeparator: ":",
                                                                           elementSeparator: ",",
                                                                           supportsSpacing: true)
        
        // Container for any transformer object
        public static let transformationContainer: BlockContainer = .init(opener: "<",
                                                                          closure: ">",
                                                                          supportsSpacing: false)
        
        
        /// An array of all different container types
        public static var allContainerTypes: [BlockContainer] { return [self.objectContainer,
                                                                        self.arrayContainer,
                                                                        self.dictionaryContainer,
                                                                        self.transformationContainer] }
        
        /// Standard Pattern matcher
        public enum Pattern: Comparable,
                             CustomStringConvertible,
                             LittleWebServerExpressibleByStringInterpolation {
            
            /// Exact Match Pattern
            case exactMatch(String)
            /// Regular Expression Pattern
            case regex(NSRegularExpression)
            
            /// String representation of the pattern
            /// If has prefix ^ and suffix $ its a regular expression
            /// otherwise is an exact match
            public var string: String {
                switch self {
                    case .exactMatch(let rtn): return rtn
                    case .regex(let regex): return regex.pattern
                }
            }
            
            public var description: String { return self.string }
            
            /// The exactMatch value if set
            public var exactMatch: String? {
                guard case .exactMatch(let rtn) = self else { return nil }
                return rtn
            }
            
            /// The regular expression value if set
            public var expression: NSRegularExpression? {
                guard case .regex(let rtn) = self else { return nil }
                return rtn
            }
            
            public var expressionString: String? {
                guard let exp = self.expression else { return nil }
                return exp.pattern
            }
            
            /// The object sort order
            fileprivate var sortOrderScore: Int {
                switch self {
                case .exactMatch(_): return 1
                case .regex(_): return 2
                }
            }
            
            public init(_ value: String) throws {
                if value.hasPrefix("^") && value.hasSuffix("$") {
                    self = .regex(try NSRegularExpression.init(pattern: value))
                } else {
                    self = .exactMatch(value)
                }
            }
            
            public init(stringLiteral value: String) {
                guard let nv = (try? Pattern(value)) else {
                    preconditionFailure("Invalid regular expression '\(value)'")
                }
                self = nv
            }
            
            /// Test the given pattern
            public func test(_ value: String) -> Bool {
                switch self {
                    case .exactMatch(let v): return value == v
                    case .regex(let r):
                        let matches = r.matches(in: value, range: NSRange(value)!)
                        return (matches.count > 0)
                }
            }
            
            public static func ==(lhs: Pattern, rhs: Pattern) -> Bool {
                switch (lhs, rhs) {
                    case (.exactMatch(let lhsV), .exactMatch(let rhsV)): return lhsV == rhsV
                    case (.regex(let lhsR), .regex(let rhsR)): return lhsR.pattern == rhsR.pattern
                    default: return false
                }
            }
            
            public static func <(lhs: Pattern, rhs: Pattern) -> Bool {
                
                if lhs.sortOrderScore < rhs.sortOrderScore { return false }
                if let lhsV = lhs.exactMatch, let rhsV = rhs.exactMatch { return lhsV < rhsV }
                if let lhsP = lhs.expression?.pattern, let rhsP = rhs.expression?.pattern { return lhsP < rhsP }
                
                return false
                
            }
        }
        
        /// An object of one or more Patterns
        public indirect enum PatternGroup: Comparable {
            /// The AND string separator
            public static var AND_OPERATOR: String { return "&&" }
            // The OR string separator
            public static var OR_OPERATOR: String { return "||" }
            
            /// Represents a single pattern
            case single(Pattern)
            /// Represents a pattern and a group
            case and(PatternGroup, PatternGroup)
            /// Represents a pattern or a group
            case or(PatternGroup, PatternGroup)
            
            /// Indicator if this is a single pattern or not
            public var isSinglePattern: Bool {
                guard case .single(_) = self else { return false }
                return true
            }
            
            /// Indicator if this is an AND or OR pattern
            private var hasGroup: Bool {
                return !self.isSinglePattern
            }
            
            
            /// Returns the single pattern if set
            public var singlePattern: Pattern? {
                guard case .single(let rtn) = self else { return nil }
                return rtn
            }
            
            /// String representation of the group pattern
            public var string: String {
                switch self {
                    case .single(let c): return c.string
                    case .and(let c, let g):
                        var rtn = c.string + " \(PatternGroup.AND_OPERATOR) "
                        let hasG = g.hasGroup
                        if hasG { rtn += "(" }
                        rtn += g.string
                        if hasG { rtn += ")" }
                        return rtn
                    case .or(let c, let g):
                        var rtn = c.string + " \(PatternGroup.OR_OPERATOR) "
                        let hasG = g.hasGroup
                        if hasG { rtn += "(" }
                        rtn += g.string
                        if hasG { rtn += ")" }
                        return rtn
                }
            }
            
            public var description: String { return self.string }
            
            internal init(_ value: String, isLiteralInit: Bool) throws {
                var value = value
                if value.hasPrefix("(") {
                    guard value.hasSuffix(")") else {
                        if isLiteralInit {
                            preconditionFailure("Missing closing ')' at end of string '\(value)'")
                        } else {
                            throw Error.missingSuffix(value, suffix: ")")
                        }
                    }
                    // remove (
                    value.removeFirst()
                    // remove )
                    value.removeLast()
                }
                let rAnd = value.range(of: " \(PatternGroup.AND_OPERATOR) ")
                let rOr = value.range(of: " \(PatternGroup.OR_OPERATOR) ")
                if rAnd == nil && rOr == nil {
                    if isLiteralInit {
                        self = .single(Pattern(stringLiteral: value))
                    } else {
                        self = .single(try Pattern(value))
                    }
                } else {
                    if (rAnd?.lowerBound ?? value.endIndex) < (rOr?.lowerBound ?? value.endIndex) {
                        let conditionString = String(value[value.startIndex..<rAnd!.lowerBound])
                        let rest = String(value[rAnd!.upperBound..<value.endIndex])
                        let cnd: Pattern
                        if isLiteralInit {
                            cnd = .init(stringLiteral: conditionString)
                        } else {
                            cnd = try .init(conditionString)
                        }
                        
                        self = .and(.single(cnd), try .init(rest, isLiteralInit: isLiteralInit))
                        
                    } else {
                        let conditionString = String(value[value.startIndex..<rOr!.lowerBound])
                        let rest = String(value[rOr!.upperBound..<value.endIndex])
                        let cnd: Pattern
                        if isLiteralInit {
                            cnd = .init(stringLiteral: conditionString)
                        } else {
                            cnd = try .init(conditionString)
                        }
                        
                        self = .or(.single(cnd), try .init(rest, isLiteralInit: isLiteralInit))
                    }
                    
                    
                }
            }
            
            /// Allows a way to validate each Pattern object in the group and sub groups
            internal func validatePatterns(_ validate: (Pattern) -> Void) {
                switch self {
                    case .single(let p): validate(p)
                    case .and(let p, let pg):
                        p.validatePatterns(validate)
                        pg.validatePatterns(validate)
                    case .or(let p, let pg):
                        p.validatePatterns(validate)
                        pg.validatePatterns(validate)
                }
            }
            
            /// Test the given string agains the pattern group
            public func test(_ value: String) -> Bool {
                switch self {
                    case .single(let c): return c.test(value)
                    case .and(let g, let c): return c.test(value) && g.test(value)
                    case .or(let g, let c): return c.test(value) || g.test(value)
                }
            }
            
            public static func ==(lhs: PatternGroup, rhs: PatternGroup) -> Bool {
                switch (lhs, rhs) {
                    case (.single(let lhsC), .single(let rhsC)): return lhsC == rhsC
                    case (.and(let lhsC, let lhsG), .and(let rhsC, let rhsG)): return lhsC == rhsC && lhsG == rhsG
                    case (.or(let lhsC, let lhsG), .or(let rhsC, let rhsG)): return lhsC == rhsC && lhsG == rhsG
                    default: return false
                }
            }
            
            public static func <(lhs: PatternGroup, rhs: PatternGroup) -> Bool {
                
                // order goes single, and, then or
                switch (lhs, rhs) {
                    case (.single(let lhsC), .single(let rhsC)): return lhsC < rhsC
                    case (.single(_), .and(_,_)): return true
                    case (.single(_), .or(_,_)): return true
                    case (.and(_,_), .or(_,_)): return true
                    case (.and(let lhsC, let lhsG), .and(let rhsC, let rhsG)):
                        if lhsC < rhsC { return true }
                        if lhsC > rhsC { return false }
                        return lhsG < rhsG
                    case (.or(let lhsC, let lhsG), .or(let rhsC, let rhsG)):
                        if lhsC < rhsC { return true }
                        if lhsC > rhsC { return false }
                        return lhsG < rhsG
                        
                    default: return false
                }
            }
            
        }
        
        public typealias ParameterPatternGroup = PatternGroup
    }
    
    
    
    /// The pattern criteria for a path component
    public enum PathComponentPattern: Comparable,
                                      CustomStringConvertible,
                                      LittleWebServerExpressibleByStringInterpolation {
        
        /// String representation of the anything value
        public static let ANYTHING_STRING: String = "*"
        /// String representation of the anythingHereafter value
        public static let ANYTHING_HEREAFTER_STRING: String = "**"
        
        /// Anything pattern.  Will accept any Path component value
        case anything
        /// Anything Hereafter pattern.  Will accept any Path and child path component values
        case anythingHereafter
        /// Any folder (path ending with /)
        case folder
        /// Specific group pattern
        case condition(Parsing.PatternGroup)
        
        /// The string representation of the pattern
        public var string: String {
            switch self {
                case .anything: return PathComponentPattern.ANYTHING_STRING
                case .anythingHereafter: return PathComponentPattern.ANYTHING_HEREAFTER_STRING
                case .condition(let c): return c.string
                case .folder: return "/"
                
            }
        }
        
        public var description: String { return self.string }
        
        /// Indicator if this is an Anything pattern
        public var isAnything: Bool {
            guard case .anything = self else { return false }
            return true
        }
        
        /// Indicator if this is an Anything Hereafter pattern
        public var isAnythingHereafter: Bool {
            guard case .anythingHereafter = self else { return false }
            return true
        }
        
        /// Returns the group pattern if this is a conditional pattern, otherwise returns nil
        public var pattern: Parsing.PatternGroup? {
            guard case .condition(let c) = self else { return nil }
            return c
        }
        
        /// The object sort order
        fileprivate var sortOrderScore: Int {
            switch self {
                case .folder: return  1
                case .condition(_): return 2
                case .anything: return 3
                case .anythingHereafter: return 4
            }
        }
        
        
        internal init(_ value: String, isLiteralInit: Bool) throws {
            if value.isEmpty || value == "/" {
                self = .folder
            } else if value == PathComponentPattern.ANYTHING_STRING {
                self = .anything
            } else if value == PathComponentPattern.ANYTHING_HEREAFTER_STRING {
                self = .anythingHereafter
            } else {
                self = .condition(try Parsing.PatternGroup(value, isLiteralInit: isLiteralInit))
            }
        }
        
        public init(_ value: String) throws {
            try self.init(value, isLiteralInit: false)
        }
        
        public init(stringLiteral value: String) {
            try! self.init(value, isLiteralInit: true)
        }
        
        public static func exactMatch(_ value: String) -> PathComponentPattern { return .condition(.single(.exactMatch(value))) }
        public static func regex(_ regex: NSRegularExpression) -> PathComponentPattern { return .condition(.single(.regex(regex))) }
        
        /// Test the given path component
        public func test(_ value: String) -> Bool {
            switch self {
                case .anything, .anythingHereafter: return true
                case .folder: return value.isEmpty || value == "/"
                case .condition(let c): return c.test(value)
            }
        }
        
        public static func ==(lhs: PathComponentPattern, rhs: PathComponentPattern) -> Bool {
            switch (lhs, rhs) {
                case (.anything, .anything): return true
                case (.folder, .folder): return true
                case (.anythingHereafter, .anythingHereafter): return true
                case (.condition(let lhsC), .condition(let rhsC)): return lhsC == rhsC
                default: return false
            }
        }
        
        public static func <(lhs: PathComponentPattern, rhs: PathComponentPattern) -> Bool {
            
            if lhs.sortOrderScore < rhs.sortOrderScore { return true }
            if lhs.sortOrderScore > rhs.sortOrderScore { return false }
            
            switch (lhs, rhs) {
                case (.anything, .anything): return false
                case (.folder, .folder): return false
                case (.anythingHereafter, .anythingHereafter): return false
                case (.condition(let lhsC), .condition(let rhsC)): return lhsC < rhsC
                default: return false
            }
            
        }
    }
    
    /// Transformer object.  Use to tranform string object to a given object
    public struct Transformation: Equatable,
                                  CustomStringConvertible,
                                  LittleWebServerExpressibleByStringInterpolation {
        
        public enum Error: Swift.Error {
            case missingStringTransformer(key: String)
        }
        
        public let string: String
        
        public var description: String { return self.string }
        
        public init(_ value: String) throws {
            self.string = value
        }
        public init(stringLiteral value: String) {
            self.string = value
        }
        public func parse(_ values: [String], using server: LittleWebServer) throws -> [Any]? {
            guard let t = server.getStringTransformer(forKey: self.string) else {
                throw Error.missingStringTransformer(key: self.string)
            }
            var rtn: [Any] = []
            for v in values {
                guard let tv = t(v) else {
                    return nil
                }
                rtn.append(tv)
            }
            return rtn
        }
        
        public func parse(_ value: String, using server: LittleWebServer) throws -> Any? {
            guard let t = server.getStringTransformer(forKey: self.string) else {
                throw Error.missingStringTransformer(key: self.string)
            }
            
            return t(value)
        }
        
        public static func ==(lhs: Transformation, rhs: Transformation) -> Bool {
            return lhs.string == rhs.string
        }
    }
    
    /// Representation of a Parameter Conditions
    /// Order must be kept, but each value is optional
    ///
    ///     * Pattern: "? [{condtion/condtion group} , { condition/condition group }] <Tranformation>"
    ///             ?: Indicates condition is optional
    ///             [{condition/condition group}...]: An array of pattern groups to match agains.  If any match then success
    ///             <Transformation>: The String identifier of an type of object to tranform to
    ///     * Examples: ? [ { ^ [0-9]+$ } ] <Int> <-- Can be optional, must be numeric and will convert to Int
    ///             ? [ { ^[0-9]+,[0-9]+$ } ] <Point> <-- Can be optional must be numeric,numeric and will convert to Point (x: Int, y: Int)
    ///             [ { ^[0-9]+,[0-9]+$ } ] <Point> <-- Must be numeric,numeric and will convert to Point (x: Int, y: Int)
    ///             [ { ^(valueA)|(valueB)$ } ] <-- Must match pattern ^(valueA)|(valueB)$ meaning must equal valueA or valueB
    ///             [ { valueC } ] <-- Must match valueC
    ///             <Int> <-- Must convert to Int
    public struct ParameterConditions: Equatable,
                                       CustomStringConvertible,
                                       LittleWebServerExpressibleByStringInterpolation {
        /// Indicator if the parameter condition is optional
        public let optional: Bool
        /// The pattern conditions to try and apply to this parameter
        /// Each one is consdered an OR
        public let conditions: [Parsing.ParameterPatternGroup]
        /// How to transofrm the parameter for use later
        public let transformation: Transformation?
        
        /// String representation of the pattern conditions
        public var string: String {
            var rtn: String = ""
            if self.optional { rtn += "?" }
            if self.conditions.count > 0 {
                if !rtn.isEmpty { rtn += " " }
                rtn += LittleWebServerRoutePathConditions.Parsing.arrayContainer.make(self.conditions.map({ return $0.string }),
                                                                       with: LittleWebServerRoutePathConditions.Parsing.objectContainer)
            }
            if let t = self.transformation {
                if !rtn.isEmpty { rtn += " " }
                rtn += LittleWebServerRoutePathConditions.Parsing.transformationContainer.make(t.string)
            }
            
            return rtn
            
        }
        
        public var description: String { return self.string }
        
        private init(_ value: String, isLiteralInit: Bool) throws {
            //print("Parameter Conditions: '\(value)'")
            var opt: Bool = false
            var condts: [Parsing.ParameterPatternGroup] = []
            var trns: Transformation? = nil
            var workingString = value
            while !workingString.isEmpty {
                if workingString.hasPrefix("?") {
                    opt = true
                    workingString.removeFirst()
                    if workingString.hasPrefix(" ") {
                        workingString.removeFirst()
                    }
                } else if workingString.hasPrefix(LittleWebServerRoutePathConditions.Parsing.arrayContainer.opener) {
                    
                    let details = try LittleWebServerRoutePathConditions.Parsing.arrayContainer.parseFromStringElements(elementContainer: LittleWebServerRoutePathConditions.Parsing.objectContainer,
                                                                                        from: workingString,
                                                                                        isLiteralInit: isLiteralInit) { s throws -> Parsing.ParameterPatternGroup in
                        return try Parsing.ParameterPatternGroup(s, isLiteralInit: isLiteralInit)
                    }
                    
                    guard details != nil else {
                        if isLiteralInit {
                            preconditionFailure("Invalid Parameter Array. Missing closing block '\(LittleWebServerRoutePathConditions.Parsing.arrayContainer.closure)' in '\(workingString)'")
                        } else {
                            throw LittleWebServerRoutePathConditions.Error.invalidParmeterArray(workingString, message: "Missing closing '\(LittleWebServerRoutePathConditions.Parsing.arrayContainer.closure)'")
                        }
                    }
                    
                    condts = details!.elements
                    
                    workingString = String(workingString[details!.outer.upperBound..<workingString.endIndex])
                    if workingString.hasPrefix(" ") { workingString.removeFirst() }
                /*} else if workingString.hasPrefix("^") {*/
                    
                } else if workingString.hasPrefix(LittleWebServerRoutePathConditions.Parsing.transformationContainer.opener) {
                    guard let details = LittleWebServerRoutePathConditions.Parsing.transformationContainer.parse(from: workingString) else {
                        if isLiteralInit {
                            preconditionFailure("Invalid Parameter Transformer. Missing closing block '\(LittleWebServerRoutePathConditions.Parsing.transformationContainer.closure)' in '\(workingString)'")
                        } else {
                            throw LittleWebServerRoutePathConditions.Error.invalidParmeterTransformer(workingString, message: "Missing closing '\(LittleWebServerRoutePathConditions.Parsing.transformationContainer.closure)'")
                        }
                    }
                    
                    if isLiteralInit {
                        trns = Transformation(stringLiteral: String(workingString[details.inner]))
                    } else {
                        trns = try Transformation(String(workingString[details.inner]))
                    }
                    
                    
                    
                    workingString = String(workingString[details.outer.upperBound..<workingString.endIndex])
                } else {
                    if isLiteralInit {
                        preconditionFailure("Invalid character '\(workingString.first!)' found in '\(workingString)'. Expected one of the following: '?', '\(LittleWebServerRoutePathConditions.Parsing.arrayContainer.opener)', '\(LittleWebServerRoutePathConditions.Parsing.transformationContainer.opener)'")
                    } else {
                        throw LittleWebServerRoutePathConditions.Error.invalidCharacterFound(workingString,
                                                                                         character: workingString.first!,
                                                                                         expecting: ["?",
                                                                                                     LittleWebServerRoutePathConditions.Parsing.arrayContainer.opener,
                                                                                                     LittleWebServerRoutePathConditions.Parsing.transformationContainer.opener])
                    }
                }
            }
            
            
            self.optional = opt
            self.conditions = condts
            self.transformation = trns
        }
        
        public init(_ value: String) throws {
            try self.init(value, isLiteralInit: false)
        }
        
        public init(stringLiteral value: String) {
            try! self.init(value, isLiteralInit: true)
        }
        
        //internal func test(_ value: String?, using server: LittleWebServer) -> Any?? {
        internal func test(_ value: [String], using server: LittleWebServer) throws -> (success: Bool, transformation: [Any]?)? {
            guard !value.isEmpty else {
                guard self.optional else {
                    return nil
                }
                return (success: true, transformation: nil)
            }
            
            var transformations: [Any] = []
            
            for v in value {
                // Find if any conditions are successfull
                guard self.conditions.contains(where: { return $0.test(v) }) else {
                    return (success: false, transformation: nil)
                }
                
                guard let tf = self.transformation else {
                    continue
                }
                
                
                guard let t = try tf.parse(value, using: server) else {
                    return (success: false, transformation: nil)
                }
                
                transformations.append(t)
                
            }
            
            if transformations.count > 0 {
                return (success: true, transformation: transformations)
            } else {
                return (success: true, transformation: nil)
            }
        }
        
        public static func ==(lhs: ParameterConditions, rhs: ParameterConditions) -> Bool {
            guard lhs.optional == rhs.optional else { return false }
            return lhs.conditions.sameElements(as: rhs.conditions)
        }
    }
    // :identifer{ {condition} <Transformation> { @parameter : { condition , condition ] , @parameter : { condition , condition } } }
    // *{ <Transformation> { @parameter : { condition , condition } , @parameter : { condition , condition } } }
    public struct RoutePathConditionComponent: Comparable,
                                               CustomStringConvertible,
                                               LittleWebServerSimilarOperator/*,
                                               LittleWebServerExpressibleByStringInterpolation*/ {
        let identifier: String?
        let pathCondition: PathComponentPattern
        public var transformation: Transformation?
        
        let parameterConditions: [String: ParameterConditions]
        
        public var isAnythingHereafter: Bool {
            return self.pathCondition.isAnythingHereafter
        }
        
        /// String representation of the component
        public var string: String {
            var putConditionInBody: Bool = true
            var rtn: String = ""
            if let id = self.identifier {
                rtn = ":\(id)"
            } else if self.pathCondition == .anything {
                rtn = PathComponentPattern.anything.string
                putConditionInBody = false
            } else if self.pathCondition == .anythingHereafter {
                rtn = PathComponentPattern.anythingHereafter.string
                putConditionInBody = false
            } else if let pathValue = self.pathCondition.pattern?.singlePattern?.exactMatch,
                      self.identifier == nil {
                rtn = pathValue
                putConditionInBody = false
            }
            
            var body: String = ""
            if putConditionInBody && self.pathCondition != .anything && self.pathCondition != .anythingHereafter {
                body = self.pathCondition.string
            }
            if let t = self.transformation {
                if !body.isEmpty { body += " " }
                body += LittleWebServerRoutePathConditions.Parsing.transformationContainer.make(t.string)
            }
            
            if self.parameterConditions.count > 0 {
                if !body.isEmpty { body += " " }
                
                body += LittleWebServerRoutePathConditions.Parsing.dictionaryContainer.make(self.parameterConditions.mapValues({ return $0.string }),
                                                                            with: LittleWebServerRoutePathConditions.Parsing.objectContainer)
                
            }
            
            if !body.isEmpty {
                rtn += LittleWebServerRoutePathConditions.Parsing.objectContainer.make(body)
            }
            return rtn
        }
        
        public var description: String { return self.string }
        
        private init(identifier: String?,
                     condition: PathComponentPattern,
                     tranformation: Transformation?,
                     parameterConditions: [String: ParameterConditions]) {
            if let id = identifier {
                precondition(!id.contains("/"), "Identifier can not contain '/'")
                precondition(!id.contains("\\"), "Identifier can not contain '\\'")
            }
            if let p = condition.pattern {
                p.validatePatterns {
                    if let v = $0.exactMatch {
                        precondition(v.contains("/"), "Pattern Path can not contain '/'")
                        precondition(v.contains("\\"), "Pattern Path can not contain '\\'")
                    }
                }
            }
            
            self.identifier = identifier
            self.pathCondition = condition
            
            self.transformation = tranformation
            self.parameterConditions = parameterConditions
        }
        
        public static var folder: RoutePathConditionComponent {
            return .init(identifier: nil,
                        condition: .folder,
                         tranformation: nil,
                         parameterConditions: [:])
        }
        
        public static func anything(tranformation: Transformation? = nil,
                                    parameterConditions: [String: ParameterConditions] = [:]) -> RoutePathConditionComponent {
            return .init(identifier: nil,
                         condition: .anything,
                         tranformation: tranformation,
                         parameterConditions: parameterConditions)
        }
        
        public static func anythingHereafter(tranformation: Transformation? = nil,
                                             parameterConditions: [String: ParameterConditions] = [:]) -> RoutePathConditionComponent {
            return .init(identifier: nil,
                         condition: .anythingHereafter,
                         tranformation: tranformation,
                         parameterConditions: parameterConditions)
        }
        
        public static func path(identifier: String? = nil,
                                condition: Parsing.PatternGroup,
                                tranformation: Transformation? = nil,
                                parameterConditions: [String: ParameterConditions] = [:]) -> RoutePathConditionComponent {
            return .init(identifier: identifier,
                         condition: .condition(condition),
                         tranformation: tranformation,
                         parameterConditions: parameterConditions)
        }
        
        private init(_ value: String, isLiteralInit: Bool) throws {
            var ident: String? = nil
            var cond: PathComponentPattern? = nil
            var tranformation: Transformation? = nil
            var paramConds: [String: ParameterConditions] = [:]
            
            var workingString = value
            if workingString.hasPrefix(":") {
                workingString.removeFirst()
                if let r = workingString.range(of: LittleWebServerRoutePathConditions.Parsing.objectContainer.opener) {
                    ident = String(workingString[workingString.startIndex..<r.lowerBound])
                    workingString = String(workingString[r.lowerBound..<workingString.endIndex])
                } else {
                    ident = workingString
                    workingString = ""
                }
            } else if workingString.hasPrefix(PathComponentPattern.anythingHereafter.string) {
                ident = nil
                cond = .anythingHereafter
                if let r = workingString.range(of: LittleWebServerRoutePathConditions.Parsing.objectContainer.opener) {
                    workingString = String(workingString[r.lowerBound..<workingString.endIndex])
                } else if workingString == PathComponentPattern.anythingHereafter.string {
                    workingString = ""
                } else {
                    if isLiteralInit {
                        preconditionFailure("Extra characters in Anything After path '\(workingString)'")
                    } else {
                        throw Error.extraCharactersInAnythingHereafterPath(workingString)
                    }
                }
                
            } else if workingString.hasPrefix(PathComponentPattern.anything.string) {
                ident = nil
                cond = .anything
                if let r = workingString.range(of: LittleWebServerRoutePathConditions.Parsing.objectContainer.opener) {
                    workingString = String(workingString[r.lowerBound..<workingString.endIndex])
                } else if workingString == PathComponentPattern.anything.string {
                    workingString = ""
                } else {
                    if isLiteralInit {
                        preconditionFailure("Extra characters in Anything path '\(workingString)'")
                    } else {
                        throw Error.extraCharactersInAnythingPath(workingString)
                    }
                }
            } else if !workingString.hasPrefix(LittleWebServerRoutePathConditions.Parsing.objectContainer.opener) {
                ident = nil
                
                var value: String = workingString
                if let r = workingString.range(of: LittleWebServerRoutePathConditions.Parsing.objectContainer.opener) {
                    value = String(workingString[workingString.startIndex..<r.lowerBound])
                    workingString = String(workingString[r.lowerBound...])
                } else {
                    workingString = ""
                }
                
                
                
                cond = .condition(.single(.exactMatch(value)))
                
            }
            
            while workingString.hasPrefix(" ") { workingString.removeFirst() }
            
            
            if !workingString.isEmpty {
                //print("Working String: '\(workingString)'")
                guard let escappedWorkingString = LittleWebServerRoutePathConditions.Parsing.objectContainer.parse(from: workingString)?.innerValue(from: workingString) else {
                    if isLiteralInit {
                        preconditionFailure("Invalid object container. Expected to start with '\(LittleWebServerRoutePathConditions.Parsing.objectContainer.opener)'")
                    } else {
                        throw Error.invalidObjectContainer(workingString,
                                                           expectedStart: LittleWebServerRoutePathConditions.Parsing.objectContainer.opener,
                                                           expectedEnd: LittleWebServerRoutePathConditions.Parsing.objectContainer.closure,
                                                           foundStart: workingString.first!,
                                                           foundEnd: workingString.last!,
                                                           message: "Invalid path details")
                    }
                }
                
                workingString = escappedWorkingString
                while workingString.hasPrefix(" ") { workingString.removeFirst() }
                //print("Escaped Working String: '\(workingString)'")
                
                func isDict(_ string: String) -> Bool {
                    guard string.hasPrefix(LittleWebServerRoutePathConditions.Parsing.dictionaryContainer.opener) else {
                            
                            return false
                        }
                    
                    var idx = string.index(after: string.startIndex)
                    while idx < string.endIndex && string[idx] == " " {
                        idx = string.index(after: idx)
                    }
                    guard idx < string.endIndex else {
                        return false
                    }
                    
                    return string[idx] == LittleWebServerRoutePathConditions.Parsing.dictionaryContainer.keyPrefix
                }
                
                // specifically look for anythinghere after
                if workingString.hasPrefix("**") {
                    if workingString.count == 2 {
                        cond = .anythingHereafter
                        workingString = ""
                    } else if workingString[workingString.index(workingString.startIndex, offsetBy: 2)] == " " {
                        cond = .anythingHereafter
                        workingString.removeFirst(3)
                    }
                } else if workingString.hasPrefix("*") {
                    // specifically anything
                    if workingString.count == 1 {
                        cond = .anything
                        workingString = ""
                    } else if workingString[workingString.index(after: workingString.startIndex)] == " " {
                        cond = .anything
                        workingString.removeFirst(2)
                    }
                } else if workingString.hasPrefix("^"),
                       let r = workingString.range(of: "$") {
                    // specifically a pattern
                    let regexStr = String(workingString[..<r.upperBound])
                    workingString = String(workingString[r.upperBound...])
                    while workingString.hasPrefix(" ") { workingString.removeFirst() }
                    
                    cond = try PathComponentPattern(regexStr)
                }
                
                    
                if !workingString.isEmpty &&
                    workingString.hasPrefix(LittleWebServerRoutePathConditions.Parsing.objectContainer.opener) &&
                    !isDict(workingString) {
                    
                    
                    guard let block = LittleWebServerRoutePathConditions.Parsing.objectContainer.parse(from: workingString) else {
                        throw Error.invalidObjectContainer(workingString,
                                                           expectedStart: LittleWebServerRoutePathConditions.Parsing.arrayContainer.opener,
                                                           expectedEnd: LittleWebServerRoutePathConditions.Parsing.arrayContainer.closure,
                                                           foundStart: workingString.first!,
                                                           foundEnd: workingString.last!,
                                                           message: "Invalid object condition details")
                    }
                    
                    
                    
                    
                    let newCond = try PathComponentPattern(block.innerValue(from: workingString),
                                                    isLiteralInit: isLiteralInit)
                    
                    workingString =  block.afterBlock(from: workingString)
                    if workingString.hasPrefix(" ") { workingString.removeFirst() }
                    
                    if cond == nil { cond = newCond }
                    else {
                        throw Error.pathPatternAlreadyExists(current: cond!, new: newCond)
                    }
                    
                    
                    /*
                    let tR = workingString.range(of: RoutePathConditions.Parsing.transformationContainer.opener)
                    let pR = workingString.range(of: RoutePathConditions.Parsing.arrayContainer.opener)
                    
                
                    
                    let startCondIndex = workingString.startIndex
                    var endCondIndex =  workingString.endIndex
                    if let t = tR, let p = pR {
                        if t.lowerBound < p.lowerBound {
                            endCondIndex = t.lowerBound
                        } else {
                            endCondIndex = p.lowerBound
                        }
                    } else if let t = tR {
                        endCondIndex = t.lowerBound
                    } else if let p = pR {
                        endCondIndex = p.lowerBound
                    }
                    
                    let condStr = String(workingString[startCondIndex..<endCondIndex])
                        
                    
                    workingString = String(workingString[endCondIndex...])
                    
                    
                    cond = try PathComponentPattern(condStr, isLiteralInit: isLiteralInit)
                    */
                }
                
                if !workingString.isEmpty &&
                    workingString.first == LittleWebServerRoutePathConditions.Parsing.transformationContainer.opener {
                    guard let objectDetails = LittleWebServerRoutePathConditions.Parsing.transformationContainer.parse(from: workingString) else {
                        if isLiteralInit {
                            preconditionFailure("Invalid path transformation container. Expected to start with '\(LittleWebServerRoutePathConditions.Parsing.transformationContainer.opener)' and end with '\(LittleWebServerRoutePathConditions.Parsing.transformationContainer.closure)'")
                        } else {
                            throw Error.invalidObjectContainer(workingString,
                                                               expectedStart: LittleWebServerRoutePathConditions.Parsing.transformationContainer.opener,
                                                               expectedEnd: LittleWebServerRoutePathConditions.Parsing.transformationContainer.closure,
                                                               foundStart: workingString.first!,
                                                               foundEnd: workingString.last!,
                                                               message: "Invalid transformation condition details")
                        }
                    }
                    
                    let transStr = objectDetails.innerValue(from: workingString)
                    workingString = objectDetails.afterBlock(from: workingString,
                                                             parentContainer: LittleWebServerRoutePathConditions.Parsing.objectContainer)
                    if isLiteralInit {
                        tranformation = Transformation(stringLiteral: transStr)
                    } else {
                        tranformation = try Transformation(transStr)
                    }
                    
                }
                
                if !workingString.isEmpty &&
                    workingString.first == LittleWebServerRoutePathConditions.Parsing.dictionaryContainer.opener {
                    //let elementDetails: RoutePathConditions.DictionaryContainer.DictionaryClosureDetils<(key: String, value: ParameterConditions)>?
                    let elementDetails: LittleWebServerRoutePathConditions.Parsing.DictionaryContainer.DictionaryClosureDetils<(String, ParameterConditions)>?
                    elementDetails = try LittleWebServerRoutePathConditions.Parsing.dictionaryContainer.parseFromStringElements(valueContainer: LittleWebServerRoutePathConditions.Parsing.objectContainer,
                                                                                        from: workingString,
                                                                                        isLiteralInit: isLiteralInit) { (key, val) throws -> (String, ParameterConditions) in
                        let v: ParameterConditions
                        if isLiteralInit {
                            v = ParameterConditions(stringLiteral: val)
                        } else {
                            v = try ParameterConditions(val)
                        }
                        return (key, v)
                        
                    }
                    
                    guard elementDetails != nil else {
                        if isLiteralInit {
                            preconditionFailure("Unable to parse path parameter details")
                        } else {
                            
                            
                            throw Error.invalidObjectContainer(workingString,
                                                               expectedStart: LittleWebServerRoutePathConditions.Parsing.dictionaryContainer.opener,
                                                               expectedEnd: LittleWebServerRoutePathConditions.Parsing.dictionaryContainer.closure,
                                                               foundStart: workingString.first!,
                                                               foundEnd: workingString.last!,
                                                               message: "Invalid path parameter details")
                        }
                    }
                    
                    //print(elementDetails!.elements)
                    if elementDetails!.elements.count > 1 {
                        for i in 0..<(elementDetails!.elements.count-1) {
                            let outerElement = elementDetails!.elements[i]
                            for x in (i+1)..<elementDetails!.elements.count {
                                //print("\(elementDetails!.elements[x].0)==\(outerElement.0)")
                                if elementDetails!.elements[x].0 == outerElement.0 {
                                    if isLiteralInit {
                                        preconditionFailure("Duplicate parameter key found '\(outerElement.0)'")
                                    } else {
                                        
                                        
                                        throw Error.duplicateParameterKeyFound(outerElement.0)
                                    }
                                }
                            }
                        }
                    }
                    
                    paramConds = Dictionary<String, ParameterConditions>.init(uniqueKeysWithValues: elementDetails!.elements)
                    
                    workingString = String(workingString[elementDetails!.outer.upperBound...])
                    
                }
                
                // Clear out any more white space
                while workingString.hasPrefix(" ") { workingString.removeFirst() }
                
                if !workingString.isEmpty {
                    if isLiteralInit {
                        preconditionFailure("Unknown information found in string. '\(workingString)'")
                    } else {
                        
                        throw Error.foundExtraTrailingString(workingString)
                    }
                }
                
            }
            
            self.identifier = ident
            self.pathCondition = cond ?? .anything
            self.transformation = tranformation
            self.parameterConditions = paramConds
        }
        
        public init(_ value: String) throws {
            try self.init(value, isLiteralInit: false)
        }
        
        public init(stringLiteral value: String) {
            try! self.init(value, isLiteralInit: true)
        }
        
        public func testPathComponent(_ componnent: String) -> Bool {
            guard self.pathCondition.test(componnent) else { return false }
            return true
        }
        public func test(pathComponents: [String],
                         atPathIndex pathIndex: Int = 0,
                         in request: LittleWebServer.HTTP.Request,
                         using server: LittleWebServer) throws -> (identifier: String?,
                                                                   transformedValue: Any?,
                                                                   transformedParameters: [String: Any])? {
            
            var pathComponent = pathComponents[pathIndex]
            if self.pathCondition == .anythingHereafter {
                pathComponent = pathComponents.suffix(from: pathIndex).joined(separator: "/")
            }
            
            
            guard self.pathCondition.test(pathComponent) else { return nil }
            var transformedPath: Any? = nil
            if let t = self.transformation {
                guard let tv = try t.parse(pathComponent, using: server) else {
                    return nil
                }
                transformedPath = tv
            } else {
                transformedPath = pathComponent
            }
            
            var tansformedParameters: [String: Any] = [:]
            for (param, condition) in self.parameterConditions {
                
                guard let r = try condition.test(request.queryParameters(for: param),
                                                 using: server),
                      r.success else {
                    return nil
                }
                
                guard let t = r.transformation else {
                    continue
                }
                
                tansformedParameters[param] = t
                
                
            }
            
            return (identifier: self.identifier,
                    transformedValue: transformedPath,
                    transformedParameters: tansformedParameters)
            
        }
        
        
        public static func ~=(lhs: RoutePathConditionComponent, rhs: RoutePathConditionComponent) -> Bool {
            guard lhs.pathCondition == rhs.pathCondition else { return false }
            return true
            
        }
        public static func ==(lhs: RoutePathConditionComponent, rhs: RoutePathConditionComponent) -> Bool {
            guard lhs.identifier == rhs.identifier else { return false }
            guard lhs.pathCondition == rhs.pathCondition else { return false }
            guard lhs.transformation == rhs.transformation else { return false }
            return lhs.parameterConditions.sameElements(as: rhs.parameterConditions)
        }
        public static func <(lhs: RoutePathConditionComponent, rhs: RoutePathConditionComponent) -> Bool {
            if lhs.pathCondition < rhs.pathCondition { return true }
            if lhs.pathCondition > rhs.pathCondition { return false }
            if (lhs.identifier ?? "") < (rhs.identifier ?? "") { return true }
            
            return false
        }
        
    }
    /// Represents a slice of RoutePathConditions
    public struct RoutePathConditionSlice: LittleWebServerExpressibleByStringInterpolation,
                                           CustomStringConvertible,
                                           Equatable,
                                           Collection {
        internal var components: [RoutePathConditionComponent]
        
        public var startIndex: Int { return self.components.startIndex }
        public var endIndex: Int { return self.components.endIndex }
        
        public subscript(index: Int) -> RoutePathConditionComponent {
            get { return self.components[index] }
            set {
                if index < self.components.count - 1 {
                    precondition(newValue.pathCondition.isAnythingHereafter,
                                 "Anything Hereafter component can only be at the end")
                }
                self.components[index] = newValue
            }
        }
        
        public subscript(range: Range<Int>) -> RoutePathConditionSlice {
            get {
                let components = Array(self.components[range])
                return RoutePathConditionSlice(components)
            }
        }
        
        public var first: RoutePathConditionComponent? {
            return self.components.first
        }
        
        public var last: RoutePathConditionComponent? {
            return self.components.last
        }
        
        /// The string representation of the slice
        public var string: String {
            var rtn =  self.components.map({ return $0.string }).joined(separator: "/")
            if rtn.hasPrefix("/") { rtn.removeFirst() }
            return rtn
        }
        
        public var description: String { return self.string }
        
        /// Indicator if the slice has a trailing Anything Hereafter condition
        public var hasTrailingAnythingHereafter: Bool {
            return self.components.last?.pathCondition.isAnythingHereafter ?? false
        }
        
        internal init(_ components: [RoutePathConditionComponent]) {
            self.components = components
        }
        public init(_ component: RoutePathConditionComponent) {
            self.components = [component]
        }
        
        public init(value: String) throws {
            var workingValue = value
            if value.hasPrefix("/") {
                throw Error.pathSliceMustNotStartWithPathSeparator
            }
           
            //allContainerTypes
            var components:  [RoutePathConditionComponent] = []
            if workingValue.hasSuffix("/") { workingValue.removeLast() }
            
            if !workingValue.isEmpty {
                var workingString = workingValue
                var currentIndex = workingString.startIndex
                var inContainer: [Parsing.BlockContainer] = []
                while !workingString.isEmpty && currentIndex < workingString.endIndex {
                    if workingString[currentIndex] == "/" && inContainer.count == 0 {
                        let componentString = String(workingString[workingString.startIndex..<currentIndex])
                        //print("Component: '\(componentString)'")
                        //print("Current workingString: '\(workingString)'")
                        workingString = String(workingString[workingString.index(after: currentIndex)...])
                        //print("New workingString: '\(workingString)'")
                        currentIndex = workingString.startIndex
                        
                        components.append(RoutePathConditionComponent(stringLiteral: componentString))
                        
                        
                    } else {
                        // See if we're at the beginnign of new container
                        if let container = LittleWebServerRoutePathConditions.Parsing.allContainerTypes.first(where: { return $0.opener == workingString[currentIndex] }) {
                            // enter container block
                            inContainer.append(container)
                            
                        } else if let currentContianer = inContainer.last, currentContianer.closure == workingString[currentIndex] {
                            // exit container block
                            inContainer.removeLast()
                            
                        }
                        currentIndex = workingString.index(after: currentIndex)
                    }
                }
                
                if !workingString.isEmpty {
                    components.append(RoutePathConditionComponent(stringLiteral: workingString))
                }
                
                
                //self.components = value.components(separatedBy: "/").map(Component.init(stringLiteral:))
                if components.count > 1 {
                    for i in 1..<components.count {
                        if components[i-1].pathCondition == .anythingHereafter {
                            throw Error.pathComponentCanNotBeAfterAnythingHereafter
                        }
                    }
                }
            }
            
            // we had a trailing / in the path or we are the root /
            if /*value.hasSuffix("/") ||*/ value.isEmpty {
                components.append(RoutePathConditionComponent.folder)
            }
            
            self.components = components
        }
        
        public init?(_ string: String) {
            do {
                try self.init(value: string)
            } catch {
                return nil
            }
        }
        
        
        public init(stringLiteral value: String) {
            do {
                try self.init(value: value)
            } catch Error.pathSliceMustNotStartWithPathSeparator {
                preconditionFailure("Path Slice must not start with '/'")
            } catch Error.pathComponentCanNotBeAfterAnythingHereafter {
                preconditionFailure("Path Components can not be after AnythingHereafter")
            } catch {
                preconditionFailure("\(error)")
            }
        }
        
        public func index(after index: Int) -> Int {
            return self.components.index(after: index)
        }
        
        /// Append a slice to the end of the slice
        public mutating func append(_ slice: RoutePathConditionSlice) {
            precondition(self.components[self.components.count-1].pathCondition != .anythingHereafter,
                         "Can not append to path with tailing AnythingHereafter")
            self.components.append(contentsOf: slice.components)
            
        }
        
        /// Append a component to the end of the slice
        public mutating func append(_ component: RoutePathConditionComponent) {
            self.append(RoutePathConditionSlice(component))
        }
        
        /// Append an array of components to the end of the slice
        public mutating func append(contentsOf components: [RoutePathConditionComponent]) {
            self.append(RoutePathConditionSlice(components))
        }
        
        /// Append a slice to the end of the slice
        public mutating func insert(_ slice: RoutePathConditionSlice, at index: Int) {
            precondition(self.components[self.components.count-1].pathCondition != .anythingHereafter,
                         "Can not append to path with tailing AnythingHereafter")
            if index < self.components.count-1 {
                precondition(!slice.hasTrailingAnythingHereafter,
                             "When inserting to any position before the end.  The insert can not have the Anything Hereafter condition")
            }
            self.components.insert(contentsOf: slice.components, at: index)
            
        }
        
        /// Append a component to the end of the slice
        public mutating func insert(_ component: RoutePathConditionComponent, at index: Int) {
            self.insert(RoutePathConditionSlice(component), at: index)
        }
        
        /// Append an array of components to the end of the slice
        public mutating func insert(contentsOf components: [RoutePathConditionComponent], at index: Int) {
            self.insert(RoutePathConditionSlice(components), at: index)
        }
        
        @discardableResult public mutating func remove(at index: Int) -> RoutePathConditionComponent {
            return self.components.remove(at: index)
        }
        
        @discardableResult public mutating func removeFirst() -> RoutePathConditionComponent {
            return self.components.removeFirst()
        }
        
        public mutating func removeFirst(_ k: Int) {
            self.components.removeFirst(k)
        }
        
        @discardableResult public mutating func removeLast() -> RoutePathConditionComponent {
            return self.components.removeLast()
        }
        
        public mutating func removeLast(_ k: Int) {
            self.components.removeLast(k)
        }
        
        public func testPath(_ pathComponents: [String]) -> Bool {
            var currentIndex = 0
            while currentIndex < pathComponents.count && currentIndex < self.components.count {
                let component = self.components[currentIndex]
                if !component.testPathComponent(pathComponents[currentIndex]) {
                    return false
                }
                if component.isAnythingHereafter {
                    currentIndex = pathComponents.count
                } else {
                    currentIndex += 1
                }
            }
            
            return currentIndex == pathComponents.count
           
        }
        
        public func testPath(_ path: String) -> Bool {
            let pathComponents = path.split(separator: "/").map(String.init)
            return self.testPath(pathComponents)
        }
        
        public static func ==(lhs: RoutePathConditionSlice, rhs: RoutePathConditionSlice) -> Bool {
            guard lhs.components.count == rhs.components.count else { return false }
            for i in 0..<lhs.components.count {
                if lhs.components[i] != rhs.components[i] { return false }
            }
            return true
        }
        
        public static func +(lhs: RoutePathConditionSlice, rhs: RoutePathConditionSlice) -> LittleWebServerRoutePathConditions {
            var rtn = LittleWebServerRoutePathConditions(lhs.components)
            rtn.append(contentsOf: rhs.components)
            return rtn
        }
        
        
        public static func +=(lhs: inout RoutePathConditionSlice, rhs: RoutePathConditionSlice) {
            lhs.append(contentsOf: rhs.components)
        }
    }
    
    
    internal var slice: RoutePathConditionSlice
    internal var components: [RoutePathConditionComponent] { return self.slice.components }
    
    public var startIndex: Int { return self.components.startIndex }
    public var endIndex: Int { return self.components.endIndex }
    
    public subscript(index: Int) -> RoutePathConditionComponent {
        get { return self.slice[index] }
        set {
            if index < self.components.count - 1 {
                precondition(newValue.pathCondition.isAnythingHereafter,
                             "Anything Hereafter component can only be at the end")
            }
            self.slice[index] = newValue
        }
    }
    
    public subscript(range: Range<Int>) -> RoutePathConditionSlice {
        get {
            let components = Array(self.slice[range])
            return RoutePathConditionSlice(components)
        }
    }
    
    public var first: RoutePathConditionComponent? {
        return self.slice.first
    }
    
    public var last: RoutePathConditionComponent? {
        return self.slice.last
    }
    
    
    public var string: String {
        return "/" + self.slice.string
    }
    
    public var description: String { return self.string }
    
    public var hasTrailingAnythingHereafter: Bool {
        return self.slice.last?.pathCondition.isAnythingHereafter ?? false
    }
    
    private init(_ components: [RoutePathConditionComponent]) {
        self.slice = RoutePathConditionSlice(components)
    }
    public init(component: RoutePathConditionComponent) {
        self.slice = RoutePathConditionSlice(component)
    }
    public init(value: String) throws {
        var value = value
        precondition(value.hasPrefix("/"), "Path must start with '/'")
        value.removeFirst()
        
        self.slice = try RoutePathConditionSlice(value: value)
    }
    public init?(_ string: String) {
        var value = string
        precondition(value.hasPrefix("/"), "Path must start with '/'")
        value.removeFirst()
        
        guard let s =  RoutePathConditionSlice(value) else {
            return nil
        }
        self.slice = s
    }
    public init(stringLiteral value: String) {
        var value = value
        precondition(value.hasPrefix("/"), "Path must start with '/'")
        value.removeFirst()
        
        
        self.slice = RoutePathConditionSlice(stringLiteral: value)
        
    }
    
    public func testPath(_ path: String) -> Bool {
        var pathComponents = path.split(separator: "/").map(String.init)
        if path.hasSuffix("/") { pathComponents.append("") }
        return self.slice.testPath(pathComponents)
    }
    
    /// Anything pattern.  Will accept any Path component value
    public static func anything(tranformation: Transformation? = nil,
                                parameterConditions: [String: ParameterConditions] = [:]) -> LittleWebServerRoutePathConditions {
        return .init(component: .anything(tranformation: tranformation,
                                          parameterConditions: parameterConditions))
    }
    
    /// Anything Hereafter pattern.  Will accept any Path and child path component values
    public static func anythingHereafter(tranformation: Transformation? = nil,
                                         parameterConditions: [String: ParameterConditions] = [:]) -> LittleWebServerRoutePathConditions {
        return .init(component: .anythingHereafter(tranformation: tranformation,
                                                   parameterConditions: parameterConditions))
    }
    
    public func index(after index: Int) -> Int {
        return self.components.index(after: index)
    }
    
    /// Append a slice to the end of the slice
    public mutating func append(_ slice: RoutePathConditionSlice) {
        self.slice.append(contentsOf: slice.components)
        
    }
    
    /// Append a component to the end of the slice
    public mutating func append(_ component: RoutePathConditionComponent) {
        self.slice.append(RoutePathConditionSlice(component))
    }
    
    /// Append an array of components to the end of the slice
    public mutating func append(contentsOf components: [RoutePathConditionComponent]) {
        self.slice.append(RoutePathConditionSlice(components))
    }
    
    /// Append a slice to the end of the slice
    public mutating func insert(_ slice: RoutePathConditionSlice, at index: Int) {
        self.slice.insert(slice, at: index)
        
    }
    
    /// Append a component to the end of the slice
    public mutating func insert(_ component: RoutePathConditionComponent, at index: Int) {
        self.slice.insert(RoutePathConditionSlice(component), at: index)
    }
    
    /// Append an array of components to the end of the slice
    public mutating func insert(contentsOf components: [RoutePathConditionComponent], at index: Int) {
        self.slice.insert(RoutePathConditionSlice(components), at: index)
    }
    
    @discardableResult public mutating func remove(at index: Int) -> RoutePathConditionComponent {
        return self.slice.remove(at: index)
    }
    
    @discardableResult public mutating func removeFirst() -> RoutePathConditionComponent {
        return self.slice.removeFirst()
    }
    
    public mutating func removeFirst(_ k: Int) {
        self.slice.removeFirst(k)
    }
    
    @discardableResult public mutating func removeLast() -> RoutePathConditionComponent {
        return self.slice.removeLast()
    }
    
    public mutating func removeLast(_ k: Int) {
        self.slice.removeLast(k)
    }
    
    public static func ==(lhs: LittleWebServerRoutePathConditions, rhs: LittleWebServerRoutePathConditions) -> Bool {
        guard lhs.slice.count == rhs.slice.count else { return false }
        for i in 0..<lhs.slice.count {
            if lhs.slice[i] != rhs.slice[i] { return false }
        }
        return true
    }
    
    public static func +(lhs: LittleWebServerRoutePathConditions, rhs: RoutePathConditionSlice) -> LittleWebServerRoutePathConditions {
        var rtn = lhs
        rtn.append(rhs)
        return rtn
    }
    
    
    public static func +=(lhs: inout LittleWebServerRoutePathConditions, rhs: RoutePathConditionSlice) {
        lhs.append(rhs)
    }
    
    public static func +(lhs: LittleWebServerRoutePathConditions, rhs: RoutePathConditionComponent) -> LittleWebServerRoutePathConditions {
        return lhs + RoutePathConditionSlice(rhs)
    }
    
    
    public static func +=(lhs: inout LittleWebServerRoutePathConditions, rhs: RoutePathConditionComponent) {
        lhs = lhs + rhs
    }
}
