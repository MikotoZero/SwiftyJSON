//  SwiftyJSON.swift
//
//  Copyright (c) 2014 - 2017 Ruoyu Fu, Pinglin Tang
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation

// MARK: - Error
// swiftlint:disable line_length
public enum SwiftyJSONError: Int, Swift.Error {
    case unsupportedType = 999
    case indexOutOfBounds = 900
    case elementTooDeep = 902
    case wrongType = 901
    case notExist = 500
    case invalidJSON = 490
}

extension SwiftyJSONError: CustomNSError {

    /// return the error domain of SwiftyJSONError
    public static var errorDomain: String { return "com.swiftyjson.SwiftyJSON" }

    /// return the error code of SwiftyJSONError
    public var errorCode: Int { return self.rawValue }

    /// return the userInfo of SwiftyJSONError
    public var errorUserInfo: [String: Any] {
        switch self {
        case .unsupportedType:
            return [NSLocalizedDescriptionKey: "It is an unsupported type."]
        case .indexOutOfBounds:
            return [NSLocalizedDescriptionKey: "Array Index is out of bounds."]
        case .wrongType:
            return [NSLocalizedDescriptionKey: "Couldn't merge, because the JSONs differ in type on top level."]
        case .notExist:
            return [NSLocalizedDescriptionKey: "Dictionary key does not exist."]
        case .invalidJSON:
            return [NSLocalizedDescriptionKey: "JSON is invalid."]
        case .elementTooDeep:
            return [NSLocalizedDescriptionKey: "Element too deep. Increase maxObjectDepth and make sure there is no reference loop."]
        }
    }
}

// MARK: - JSON Content

/// Store raw value of JSON object
private indirect enum Content {
    case bool(Bool)
    case number(NSNumber)
    case string(String)
    case array([Any])
    case dictionary([String: Any])
    case null
    case unknown
}

extension Content {
    var type: Type {
        switch self {
        case .bool: return .bool
        case .number: return .number
        case .string: return .string
        case .array: return .array
        case .dictionary: return .dictionary
        case .null: return .null
        case .unknown: return .unknown
        }
    }
    
    var rawValue: Any {
        switch self {
        case .bool(let bool): return bool
        case .number(let number): return number
        case .string(let string): return string
        case .array(let array): return array
        case .dictionary(let dictionary): return dictionary
        case .null, .unknown: return NSNull()
        }
    }
}

extension Content {
    init(_ rawValue: Any) {
        switch unwrap(rawValue) {
        case let value as NSNumber:
            if value.isBool {
                self = .bool(value.boolValue)
            } else {
                self = .number(value)
            }
        case let value as String:
            self = .string(value)
        case let value as [Any]:
            self = .array(value)
        case let value as [String: Any]:
            self = .dictionary(value)
        case _ as NSNull:
            self = .null
        case nil:
            self = .null
        default:
            self = .unknown
        }
    }
}

/// Private method to unwarp an object recursively
private func unwrap(_ object: Any) -> Any {
    switch object {
    case let json as JSON:
        return unwrap(json.object)
    case let array as [Any]:
        return array.map(unwrap)
    case let dictionary as [String: Any]:
        return dictionary.mapValues(unwrap)
    default:
        return object
    }
}

// MARK: - JSON Type

/**
JSON's type definitions.

See http://www.json.org
*/
public enum Type: Int {
	case number
	case string
	case bool
	case array
	case dictionary
	case null
	case unknown
}

// MARK: - JSON Base

public struct JSON {
    /// Private content
    private var content: Content = .null
    
    /// Error in JSON, fileprivate setter
    public private(set) var error: SwiftyJSONError?

    /// JSON type, fileprivate setter
    public var type: Type { content.type }
    
    /// Object in JSON
    public var object: Any {
        get {
            content.rawValue
        }
        set {
            content = Content(newValue)
            error = content.type == .unknown ? SwiftyJSONError.unsupportedType : nil
        }
    }
    public static var null: JSON = .init(content: .null, error: nil)
}

// MARK: - Constructor
extension JSON {
	/**
	 Creates a JSON using the data.
	
	 - parameter data: The NSData used to convert to json.Top level object in data is an NSArray or NSDictionary
	 - parameter opt: The JSON serialization reading options. `[]` by default.
	
	 - returns: The created JSON
	 */
    public init(data: Data, options opt: JSONSerialization.ReadingOptions = []) throws {
        let object: Any = try JSONSerialization.jsonObject(with: data, options: opt)
        self.init(jsonObject: object)
    }

    /**
	 Creates a JSON object
	 - note: this does not parse a `String` into JSON, instead use `init(parseJSON: String)`
	
	 - parameter object: the object

	 - returns: the created JSON object
	 */
    public init(_ object: Any) {
        switch object {
        case let object as Data:
            do {
                try self.init(data: object)
            } catch {
                self.init(jsonObject: NSNull())
            }
        case let json as JSON:
            self = json
            self.error = nil
        default:
            self.init(jsonObject: object)
        }
    }

	/**
	 Parses the JSON string into a JSON object
	
	 - parameter jsonString: the JSON string
	
	 - returns: the created JSON object
	*/
	public init(parseJSON jsonString: String) {
		if let data = jsonString.data(using: .utf8) {
			self.init(data)
		} else {
            self = .null
		}
	}

	/**
	 Creates a JSON using the object.
	
	 - parameter jsonObject:  The object must have the following properties: All objects are NSString/String, NSNumber/Int/Float/Double/Bool, NSArray/Array, NSDictionary/Dictionary, or NSNull; All dictionary keys are NSStrings/String; NSNumbers are not NaN or infinity.
	
	 - returns: The created JSON
	 */
    private init(jsonObject: Any) {
        self.object = jsonObject
    }
}

// MARK: - Merge
extension JSON {
	/**
	 Merges another JSON into this JSON, whereas primitive values which are not present in this JSON are getting added,
	 present values getting overwritten, array values getting appended and nested JSONs getting merged the same way.
 
	 - parameter other: The JSON which gets merged into this JSON
	
	 - throws `ErrorWrongType` if the other JSONs differs in type on the top level.
	 */
    public mutating func merge(with other: JSON) throws {
        try self.merge(with: other, typecheck: true)
    }

	/**
	 Merges another JSON into this JSON and returns a new JSON, whereas primitive values which are not present in this JSON are getting added,
	 present values getting overwritten, array values getting appended and nested JSONS getting merged the same way.
	
	 - parameter other: The JSON which gets merged into this JSON
	
	 - throws `ErrorWrongType` if the other JSONs differs in type on the top level.
	
	 - returns: New merged JSON
	 */
    public func merged(with other: JSON) throws -> JSON {
        var merged = self
        try merged.merge(with: other, typecheck: true)
        return merged
    }

    /**
     Private woker function which does the actual merging
     Typecheck is set to true for the first recursion level to prevent total override of the source JSON
 	*/
 	private mutating func merge(with other: JSON, typecheck: Bool) throws {
        if type == other.type {
            switch type {
            case .dictionary:
                for (key, _) in other {
                    try self[key].merge(with: other[key], typecheck: false)
                }
            case .array:
                self = JSON((arrayObject ?? []) + (other.arrayObject ?? []))
            default:
                self = other
            }
        } else {
            if typecheck {
                throw SwiftyJSONError.wrongType
            } else {
                self = other
            }
        }
    }
}

// MARK: - Index
public enum Index<T: Any>: Comparable {
    case array(Int)
    case dictionary(DictionaryIndex<String, T>)
    case null

    static public func == (lhs: Index, rhs: Index) -> Bool {
        switch (lhs, rhs) {
        case (.array(let left), .array(let right)):           return left == right
        case (.dictionary(let left), .dictionary(let right)): return left == right
        case (.null, .null):                                  return true
        default:                                              return false
        }
    }

    static public func < (lhs: Index, rhs: Index) -> Bool {
        switch (lhs, rhs) {
        case (.array(let left), .array(let right)):           return left < right
        case (.dictionary(let left), .dictionary(let right)): return left < right
        default:                                              return false
        }
    }
    
    static public func <= (lhs: Index, rhs: Index) -> Bool {
           switch (lhs, rhs) {
           case (.array(let left), .array(let right)):           return left <= right
           case (.dictionary(let left), .dictionary(let right)): return left <= right
           case (.null, .null):                                  return true
           default:                                              return false
           }
       }

       static public func >= (lhs: Index, rhs: Index) -> Bool {
           switch (lhs, rhs) {
           case (.array(let left), .array(let right)):           return left >= right
           case (.dictionary(let left), .dictionary(let right)): return left >= right
           case (.null, .null):                                  return true
           default:                                              return false
           }
       }
}

public typealias JSONIndex = Index<JSON>
public typealias JSONRawIndex = Index<Any>

extension JSON: Swift.Collection {

    public typealias Index = JSONRawIndex

    public var startIndex: Index {
        switch content {
        case .array(let arr): return .array(arr.startIndex)
        case .dictionary(let dic): return .dictionary(dic.startIndex)
        default:          return .null
        }
    }

    public var endIndex: Index {
        switch content {
        case .array(let arr):      return .array(arr.endIndex)
        case .dictionary(let dic): return .dictionary(dic.endIndex)
        default:          return .null
        }
    }

    public func index(after i: Index) -> Index {
        switch (content, i) {
        case (.array(let value), .array(let idx)):
            return .array(value.index(after: idx))
        case (.dictionary(let value), .dictionary(let idx)):
            return .dictionary(value.index(after: idx))
        default: return .null
        }
    }
    
    public subscript (position: Index) -> (String, JSON) {
        switch (content, position) {
        case (.array(let value), .array(let idx)):
            return ("\(idx)", JSON(value[idx]))
        case (.dictionary(let value), .dictionary(let idx)):
            return (value[idx].key, JSON(value[idx].value))
        default: return ("", JSON.null)
        }
    }
}

// MARK: - Subscript

/**
 *  To mark both String and Int can be used in subscript.
 */
public enum JSONKey {
    case index(Int)
    case key(String)
}

public protocol JSONSubscriptType {
    var jsonKey: JSONKey { get }
}

extension Int: JSONSubscriptType {
    public var jsonKey: JSONKey {
        return JSONKey.index(self)
    }
}

extension String: JSONSubscriptType {
    public var jsonKey: JSONKey {
        return JSONKey.key(self)
    }
}

extension JSON {

    /// If `type` is `.array`, return json whose object is `array[index]`, otherwise return null json with error.
    private subscript(index index: Int) -> JSON {
        get {
            switch content {
            case .array(let value) where value.indices.contains(index):
                return JSON(value[index])
            case .array:
                return .init(content: .null, error: .indexOutOfBounds)
            default:
                return .init(content: .null, error:  self.error ?? .wrongType)
            }
        }
        set {
            guard
                case .array(let rawArray) = content,
                rawArray.indices.contains(index),
                newValue.error == nil
            else { return }
            var copy = rawArray
            copy[index] = newValue.object
            content = .array(copy)
        }
    }

    /// If `type` is `.dictionary`, return json whose object is `dictionary[key]` , otherwise return null json with error.
    private subscript(key key: String) -> JSON {
        get {
            switch content {
            case .dictionary(let value):
                if let o = value[key] {
                    return JSON(o)
                } else {
                    return .init(content: .null, error: .notExist)
                }
            default:
                return .init(content: .null, error: self.error ?? SwiftyJSONError.wrongType)
            }
        }
        set {
            guard
                newValue.error == nil,
                case .dictionary(let rawDictionary) = content
            else {
                return
            }
            var copy = rawDictionary
            copy[key] = newValue.object
            content = .dictionary(copy)
        }
    }

    /// If `sub` is `Int`, return `subscript(index:)`; If `sub` is `String`,  return `subscript(key:)`.
    private subscript(sub sub: JSONSubscriptType) -> JSON {
        get {
            switch sub.jsonKey {
            case .index(let index): return self[index: index]
            case .key(let key):     return self[key: key]
            }
        }
        set {
            switch sub.jsonKey {
            case .index(let index): self[index: index] = newValue
            case .key(let key):     self[key: key] = newValue
            }
        }
    }

	/**
	 Find a json in the complex data structures by using array of Int and/or String as path.
	
	 Example:
	
	 ```
	 let json = JSON[data]
	 let path = [9,"list","person","name"]
	 let name = json[path]
	 ```
	
	 The same as: let name = json[9]["list"]["person"]["name"]
	
	 - parameter path: The target json's path.
	
	 - returns: Return a json found by the path or a null json with error
	 */
    public subscript(path: [JSONSubscriptType]) -> JSON {
        get {
            return path.reduce(self) { $0[sub: $1] }
        }
        set {
            switch path.count {
            case 0: return
            case 1: self[sub: path[0]].object = newValue.object
            default:
                var aPath = path
                aPath.remove(at: 0)
                var nextJSON = self[sub: path[0]]
                nextJSON[aPath] = newValue
                self[sub: path[0]] = nextJSON
            }
        }
    }

    /**
     Find a json in the complex data structures by using array of Int and/or String as path.

     - parameter path: The target json's path. Example:

     let name = json[9,"list","person","name"]

     The same as: let name = json[9]["list"]["person"]["name"]

     - returns: Return a json found by the path or a null json with error
     */
    public subscript(path: JSONSubscriptType...) -> JSON {
        get {
            return self[path]
        }
        set {
            self[path] = newValue
        }
    }
}

// MARK: - LiteralConvertible

extension JSON: Swift.ExpressibleByStringLiteral {

    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

    public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
        self.init(value)
    }

    public init(unicodeScalarLiteral value: StringLiteralType) {
        self.init(value)
    }
}

extension JSON: Swift.ExpressibleByIntegerLiteral {

    public init(integerLiteral value: IntegerLiteralType) {
        self.init(value)
    }
}

extension JSON: Swift.ExpressibleByBooleanLiteral {

    public init(booleanLiteral value: BooleanLiteralType) {
        self.init(value)
    }
}

extension JSON: Swift.ExpressibleByFloatLiteral {

    public init(floatLiteral value: FloatLiteralType) {
        self.init(value)
    }
}

extension JSON: Swift.ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        let dictionary = elements.reduce(into: [String: Any](), { $0[$1.0] = $1.1})
        self.init(dictionary)
    }
}

extension JSON: Swift.ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: Any...) {
        self.init(elements)
    }
}

// MARK: - Raw

extension JSON: Swift.RawRepresentable {

    public init?(rawValue: Any) {
        let json = JSON(rawValue)
        guard json.type != .unknown else { return nil }
        self = json
    }

    public var rawValue: Any {
        return object
    }

    public func rawData(options opt: JSONSerialization.WritingOptions = JSONSerialization.WritingOptions(rawValue: 0)) throws -> Data {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw SwiftyJSONError.invalidJSON
        }

        return try JSONSerialization.data(withJSONObject: object, options: opt)
	}

	public func rawString(_ encoding: String.Encoding = .utf8, options opt: JSONSerialization.WritingOptions = .prettyPrinted) -> String? {
		do {
			return try _rawString(encoding, options: [.jsonSerialization: opt])
		} catch {
			print("Could not serialize object to JSON because:", error.localizedDescription)
			return nil
		}
	}

	public func rawString(_ options: [writingOptionsKeys: Any]) -> String? {
		let encoding = options[.encoding] as? String.Encoding ?? String.Encoding.utf8
		let maxObjectDepth = options[.maxObjextDepth] as? Int ?? 10
		do {
			return try _rawString(encoding, options: options, maxObjectDepth: maxObjectDepth)
		} catch {
			print("Could not serialize object to JSON because:", error.localizedDescription)
			return nil
		}
	}

	private func _rawString(_ encoding: String.Encoding = .utf8, options: [writingOptionsKeys: Any], maxObjectDepth: Int = 10) throws -> String? {
        guard maxObjectDepth > 0 else { throw SwiftyJSONError.invalidJSON }
        switch content {
        case .dictionary:
			do {
				if !(options[.castNilToNSNull] as? Bool ?? false) {
					let jsonOption = options[.jsonSerialization] as? JSONSerialization.WritingOptions ?? JSONSerialization.WritingOptions.prettyPrinted
					let data = try rawData(options: jsonOption)
					return String(data: data, encoding: encoding)
				}

				guard let dict = object as? [String: Any?] else {
					return nil
				}
				let body = try dict.keys.map { key throws -> String in
					guard let value = dict[key] else {
						return "\"\(key)\": null"
					}
					guard let unwrappedValue = value else {
						return "\"\(key)\": null"
					}

					let nestedValue = JSON(unwrappedValue)
					guard let nestedString = try nestedValue._rawString(encoding, options: options, maxObjectDepth: maxObjectDepth - 1) else {
						throw SwiftyJSONError.elementTooDeep
					}
					if nestedValue.type == .string {
						return "\"\(key)\": \"\(nestedString.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
					} else {
						return "\"\(key)\": \(nestedString)"
					}
				}

				return "{\(body.joined(separator: ","))}"
			} catch _ {
				return nil
			}
        case .array:
            do {
				if !(options[.castNilToNSNull] as? Bool ?? false) {
					let jsonOption = options[.jsonSerialization] as? JSONSerialization.WritingOptions ?? JSONSerialization.WritingOptions.prettyPrinted
					let data = try rawData(options: jsonOption)
					return String(data: data, encoding: encoding)
				}

                guard let array = object as? [Any?] else {
                    return nil
                }
                let body = try array.map { value throws -> String in
                    guard let unwrappedValue = value else {
                        return "null"
                    }

                    let nestedValue = JSON(unwrappedValue)
                    guard let nestedString = try nestedValue._rawString(encoding, options: options, maxObjectDepth: maxObjectDepth - 1) else {
                        throw SwiftyJSONError.invalidJSON
                    }
                    if nestedValue.type == .string {
                        return "\"\(nestedString.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
                    } else {
                        return nestedString
                    }
                }

                return "[\(body.joined(separator: ","))]"
            } catch _ {
                return nil
            }
        case .string(let value): return value
        case .number(let value): return value.stringValue
        case .bool(let value):   return value.description
        case .null:   return "null"
        default:      return nil
        }
    }
}

// MARK: - Printable, DebugPrintable

extension JSON: Swift.CustomStringConvertible, Swift.CustomDebugStringConvertible {

    public var description: String {
        return rawString(options: .prettyPrinted) ?? "unknown"
    }

    public var debugDescription: String {
        return description
    }
}

// MARK: - Array

extension JSON {

    //Optional [JSON]
    public var array: [JSON]? {
        guard case .array(let value) = content else { return nil }
        return value.map(JSON.init(_:))
    }

    //Non-optional [JSON]
    public var arrayValue: [JSON] {
        return self.array ?? []
    }

    //Optional [Any]
    public var arrayObject: [Any]? {
        get {
            guard case .array(let value) = content else { return nil }
            return value
        }
        set {
            self = .init(content: newValue != nil ? .array(newValue!) : .null, error: nil)
        }
    }
}

// MARK: - Dictionary

extension JSON {

    //Optional [String : JSON]
    public var dictionary: [String: JSON]? {
        guard case .dictionary(let value) = content else { return nil }
        return value.mapValues(JSON.init(_:))
    }

    //Non-optional [String : JSON]
    public var dictionaryValue: [String: JSON] {
        return dictionary ?? [:]
    }

    //Optional [String : Any]

    public var dictionaryObject: [String: Any]? {
        get {
            guard case .dictionary(let value) = content else { return nil }
            return value
        }
        set {
            self = .init(content: newValue != nil ? .dictionary(newValue!) : .null, error: nil)
        }
    }
}

// MARK: - Bool

extension JSON { // : Swift.Bool

    //Optional bool
    public var bool: Bool? {
        get {
            guard case .bool(let value) = content else { return nil }
            return value
        }
        set {
            self = .init(content: newValue != nil ? .bool(newValue!) : .null, error: nil)
        }
    }

    //Non-optional bool
    public var boolValue: Bool {
        get {
            switch content {
            case .bool(let value):   return value
            case .number(let value): return value.boolValue
            case .string(let value): return ["true", "y", "t", "yes", "1"].contains { value.caseInsensitiveCompare($0) == .orderedSame }
            default:      return false
            }
        }
        set {
            self = .init(content: .bool(newValue), error: nil)
        }
    }
}

// MARK: - String

extension JSON {

    //Optional string
    public var string: String? {
        get {
            guard case .string(let value) = content else { return nil }
            return value
        }
        set {
            self = .init(content: newValue != nil ? .string(newValue!) : .null, error: nil)
        }
    }

    //Non-optional string
    public var stringValue: String {
        get {
            switch content {
            case .string(let value): return value
            case .number(let value): return value.stringValue
            case .bool(let value):   return String(value)
            default:      return ""
            }
        }
        set {
            self = .init(content: .string(newValue), error: nil)
        }
    }
}

// MARK: - Number

extension JSON {

    //Optional number
    public var number: NSNumber? {
        get {
            switch content {
            case .number(let value): return value
            case .bool(let value):   return NSNumber(value: value ? 1 : 0)
            default:      return nil
            }
        }
        set {
            self = .init(content: newValue != nil ? .number(newValue!) : .null, error: nil)
        }
    }

    //Non-optional number
    public var numberValue: NSNumber {
        get {
            switch content {
            case .string(let value):
                let decimal = NSDecimalNumber(string: value)
                return decimal == .notANumber ? .zero : decimal
            case .number(let value): return value
            case .bool(let value): return NSNumber(value: value ? 1 : 0)
            default: return NSNumber(value: 0.0)
            }
        }
        set {
            self = .init(content: .number(newValue), error: nil)
        }
    }
}

// MARK: - Null

extension JSON {

    public var null: NSNull? {
        set {
            self = .null
        }
        get {
            switch content {
            case .null: return NSNull()
            default:    return nil
            }
        }
    }
    public func exists() -> Bool {
        if let errorValue = error, (400...1000).contains(errorValue.errorCode) {
            return false
        }
        return true
    }
}

// MARK: - URL

extension JSON {

    //Optional URL
    public var url: URL? {
        get {
            switch content {
            case .string(let value):
                // Check for existing percent escapes first to prevent double-escaping of % character
                if value.range(of: "%[0-9A-Fa-f]{2}", options: .regularExpression, range: nil, locale: nil) != nil {
                    return Foundation.URL(string: value)
                } else if let encodedString_ = value.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) {
                    // We have to use `Foundation.URL` otherwise it conflicts with the variable name.
                    return Foundation.URL(string: encodedString_)
                } else {
                    return nil
                }
            default:
                return nil
            }
        }
        set {
            self = .init(content: newValue != nil ? .string(newValue!.absoluteString) : .null, error: nil)
        }
    }
}

// MARK: - Int, Double, Float, Int8, Int16, Int32, Int64

extension JSON {

    public var double: Double? {
        get { number?.doubleValue }
        set { number = newValue.map(NSNumber.init(value:)) }
    }

    public var doubleValue: Double {
        get { numberValue.doubleValue }
        set { numberValue = NSNumber(value: newValue) }
    }

    public var float: Float? {
        get { number?.floatValue }
        set { number = newValue.map(NSNumber.init(value:)) }
    }

    public var floatValue: Float {
        get { numberValue.floatValue }
        set { numberValue = NSNumber(value: newValue) }
    }

    public var int: Int? {
        get { number?.intValue }
        set { number = newValue.map(NSNumber.init(value:)) }
    }

    public var intValue: Int {
        get { numberValue.intValue }
        set { numberValue = NSNumber(value: newValue) }
    }

    public var uInt: UInt? {
        get { number?.uintValue }
        set { number = newValue.map(NSNumber.init(value:)) }
    }

    public var uIntValue: UInt {
        get { numberValue.uintValue }
        set { numberValue = NSNumber(value: newValue) }
    }

    public var int8: Int8? {
        get { number?.int8Value }
        set { number = newValue.map(NSNumber.init(value:)) }
    }

    public var int8Value: Int8 {
        get { numberValue.int8Value }
        set { numberValue = NSNumber(value: newValue) }
    }

    public var uInt8: UInt8? {
        get { number?.uint8Value }
        set { number = newValue.map(NSNumber.init(value:)) }
    }

    public var uInt8Value: UInt8 {
        get { numberValue.uint8Value }
        set { numberValue = NSNumber(value: newValue) }
    }

    public var int16: Int16? {
        get { number?.int16Value }
        set { number = newValue.map(NSNumber.init(value:)) }
    }

    public var int16Value: Int16 {
        get { numberValue.int16Value }
        set { numberValue = NSNumber(value: newValue) }
    }

    public var uInt16: UInt16? {
        get { number?.uint16Value }
        set { number = newValue.map(NSNumber.init(value:)) }
    }

    public var uInt16Value: UInt16 {
        get { numberValue.uint16Value }
        set { numberValue = NSNumber(value: newValue) }
    }

    public var int32: Int32? {
        get { number?.int32Value }
        set { number = newValue.map(NSNumber.init(value:)) }
    }

    public var int32Value: Int32 {
        get { numberValue.int32Value }
        set { numberValue = NSNumber(value: newValue) }
    }

    public var uInt32: UInt32? {
        get { number?.uint32Value }
        set { number = newValue.map(NSNumber.init(value:)) }
    }

    public var uInt32Value: UInt32 {
        get { numberValue.uint32Value }
        set { numberValue = NSNumber(value: newValue) }
    }

    public var int64: Int64? {
        get { number?.int64Value }
        set { number = newValue.map(NSNumber.init(value:)) }
    }

    public var int64Value: Int64 {
        get { numberValue.int64Value }
        set { numberValue = NSNumber(value: newValue) }
    }

    public var uInt64: UInt64? {
        get { number?.uint64Value }
        set { number = newValue.map(NSNumber.init(value:)) }
    }

    public var uInt64Value: UInt64 {
        get { numberValue.uint64Value }
        set { numberValue = NSNumber(value: newValue) }
    }
}

// MARK: - Comparable

extension Content: Comparable {
    
    static func == (lhs: Content, rhs: Content) -> Bool {
        switch (lhs, rhs) {
        case let (.number(l), .number(r)):          return l == r
        case let (.string(l), .string(r)):          return l == r
        case let (.bool(l), .bool(r)):              return l == r
        case let (.array(l), .array(r)):            return l as NSArray == r as NSArray
        case let (.dictionary(l), .dictionary(r)):  return l as NSDictionary == r as NSDictionary
        case (.null, .null):                        return true
        default:                                    return false
        }
    }
    
    static func <= (lhs: Content, rhs: Content) -> Bool {
        switch (lhs, rhs) {
        case let (.number(l), .number(r)):          return l <= r
        case let (.string(l), .string(r)):          return l <= r
        case let (.bool(l), .bool(r)):              return l == r
        case let (.array(l), .array(r)):            return l as NSArray == r as NSArray
        case let (.dictionary(l), .dictionary(r)):  return l as NSDictionary == r as NSDictionary
        case (.null, .null):                        return true
        default:                                    return false
        }
    }
    
    static func >= (lhs: Content, rhs: Content) -> Bool {
        switch (lhs, rhs) {
        case let (.number(l), .number(r)):          return l >= r
        case let (.string(l), .string(r)):          return l >= r
        case let (.bool(l), .bool(r)):              return l == r
        case let (.array(l), .array(r)):            return l as NSArray == r as NSArray
        case let (.dictionary(l), .dictionary(r)):  return l as NSDictionary == r as NSDictionary
        case (.null, .null):                        return true
        default:                                    return false
        }
    }
    
    static func > (lhs: Content, rhs: Content) -> Bool {
        switch (lhs, rhs) {
        case let (.number(l), .number(r)):  return l > r
        case let (.string(l), .string(r)):  return l > r
        default:                            return false
        }
    }
    
    static func < (lhs: Content, rhs: Content) -> Bool {
        switch (lhs, rhs) {
        case let (.number(l), .number(r)):  return l < r
        case let (.string(l), .string(r)):  return l < r
        default:                            return false
        }
    }
}

extension JSON: Swift.Comparable {
    public static func == (lhs: JSON, rhs: JSON) -> Bool {
        return lhs.content == rhs.content
    }
    
    public static func <= (lhs: JSON, rhs: JSON) -> Bool {
        return lhs.content <= rhs.content
    }

    public static func >= (lhs: JSON, rhs: JSON) -> Bool {
        return lhs.content >= rhs.content
    }
    
    public static func < (lhs: JSON, rhs: JSON) -> Bool {
        return lhs.content < rhs.content
    }
    
    public static func > (lhs: JSON, rhs: JSON) -> Bool {
        return lhs.content > rhs.content
    }
}

private let trueNumber = NSNumber(value: true)
private let falseNumber = NSNumber(value: false)
private let trueObjCType = String(cString: trueNumber.objCType)
private let falseObjCType = String(cString: falseNumber.objCType)

// MARK: - NSNumber: Comparable

private extension NSNumber {
     var isBool: Bool {
        let objCType = String(cString: self.objCType)
        if (self.compare(trueNumber) == .orderedSame && objCType == trueObjCType) || (self.compare(falseNumber) == .orderedSame && objCType == falseObjCType) {
            return true
        } else {
            return false
        }
    }
}

private func == (lhs: NSNumber, rhs: NSNumber) -> Bool {
    switch (lhs.isBool, rhs.isBool) {
    case (false, true): return false
    case (true, false): return false
    default:            return lhs.compare(rhs) == .orderedSame
    }
}

private func != (lhs: NSNumber, rhs: NSNumber) -> Bool {
    return !(lhs == rhs)
}

private func < (lhs: NSNumber, rhs: NSNumber) -> Bool {

    switch (lhs.isBool, rhs.isBool) {
    case (false, true): return false
    case (true, false): return false
    default:            return lhs.compare(rhs) == .orderedAscending
    }
}

private func > (lhs: NSNumber, rhs: NSNumber) -> Bool {

    switch (lhs.isBool, rhs.isBool) {
    case (false, true): return false
    case (true, false): return false
    default:            return lhs.compare(rhs) == ComparisonResult.orderedDescending
    }
}

private func <= (lhs: NSNumber, rhs: NSNumber) -> Bool {

    switch (lhs.isBool, rhs.isBool) {
    case (false, true): return false
    case (true, false): return false
    default:            return lhs.compare(rhs) != .orderedDescending
    }
}

private func >= (lhs: NSNumber, rhs: NSNumber) -> Bool {

    switch (lhs.isBool, rhs.isBool) {
    case (false, true): return false
    case (true, false): return false
    default:            return lhs.compare(rhs) != .orderedAscending
    }
}

public enum writingOptionsKeys {
	case jsonSerialization
	case castNilToNSNull
	case maxObjextDepth
	case encoding
}

// MARK: - JSON: Codable
extension JSON: Codable {
    public init(from decoder: Decoder) throws {
        guard
            let container = try? decoder.singleValueContainer(),
            !container.decodeNil()
        else {
            self = .null
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .init(content: .bool(value), error: nil)
        } else if let value = try? container.decode(Int.self) {
            self = .init(content: .number(value as NSNumber), error: nil)
        } else if let value = try? container.decode(Int8.self) {
            self = .init(content: .number(value as NSNumber), error: nil)
        } else if let value = try? container.decode(Int16.self) {
            self = .init(content: .number(value as NSNumber), error: nil)
        } else if let value = try? container.decode(Int32.self) {
            self = .init(content: .number(value as NSNumber), error: nil)
        } else if let value = try? container.decode(Int64.self) {
            self = .init(content: .number(value as NSNumber), error: nil)
        } else if let value = try? container.decode(UInt.self) {
            self = .init(content: .number(value as NSNumber), error: nil)
        } else if let value = try? container.decode(UInt8.self) {
            self = .init(content: .number(value as NSNumber), error: nil)
        } else if let value = try? container.decode(UInt16.self) {
            self = .init(content: .number(value as NSNumber), error: nil)
        } else if let value = try? container.decode(UInt32.self) {
            self = .init(content: .number(value as NSNumber), error: nil)
        } else if let value = try? container.decode(UInt64.self) {
            self = .init(content: .number(value as NSNumber), error: nil)
        } else if let value = try? container.decode(Double.self) {
            self = .init(content: .number(value as NSNumber), error: nil)
        } else if let value = try? container.decode(String.self) {
            self = .init(content: .string(value), error: nil)
        } else if let value = try? container.decode([JSON].self) {
            self = .init(value)
        } else if let value = try? container.decode([String: JSON].self) {
            self = .init(value)
        } else {
            self = .null
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if object is NSNull {
            try container.encodeNil()
            return
        }
        switch object {
        case let intValue as Int:
            try container.encode(intValue)
        case let int8Value as Int8:
            try container.encode(int8Value)
        case let int32Value as Int32:
            try container.encode(int32Value)
        case let int64Value as Int64:
            try container.encode(int64Value)
        case let uintValue as UInt:
            try container.encode(uintValue)
        case let uint8Value as UInt8:
            try container.encode(uint8Value)
        case let uint16Value as UInt16:
            try container.encode(uint16Value)
        case let uint32Value as UInt32:
            try container.encode(uint32Value)
        case let uint64Value as UInt64:
            try container.encode(uint64Value)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case is [Any]:
            let jsonValueArray = array ?? []
            try container.encode(jsonValueArray)
        case is [String: Any]:
            let jsonValueDictValue = dictionary ?? [:]
            try container.encode(jsonValueDictValue)
        default:
            break
        }
    }
}
