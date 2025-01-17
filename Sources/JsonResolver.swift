//
//  JsonResolver.swift
//
//
//  Created by Tomasz on 11/07/2024.
//

import Foundation

enum ValueType {
    case string(String)
    case int(Int64)
    case double(Double)
    case bool(Bool)
}

extension ValueType {
    func typeIsEqual(to other: ValueType) -> Bool {
        switch (self, other) {
        case (.string, .string):
            return true
        case (.int, .int):
            return true
        case (.double, .double):
            return true
        case (.bool, .bool):
            return true
        default:
            return false
        }
    }
}

extension ValueType {
    var readable: String {
        switch self {
        case .string:
            return "string"
        case .int:
            return "int"
        case .double:
            return "double"
        case .bool:
            return "bool"
        }
    }
    static func make(from readable: String) -> ValueType? {
        switch readable {
        case "string":
            return .string("")
        case "int":
            return .int(0)
        case "double":
            return .double(0)
        case "bool":
            return .bool(false)
        default:
            return nil
        }
    }
}

struct DatabaseValue {
    let name: String
    let type: ValueType
}

enum JsonResolverError: Error {
    case typeNotSupported(key: String, type: String)
    case typeMismatch(key: String, registered: String, received: String)
}

enum JsonResolver {
    static let logTag = "JsonResolver"
    static func resolve(_ json: JSON) throws -> [DatabaseValue] {
        var values: [DatabaseValue] = []
        for (name, value) in json.dictionaryValue {
            switch value.type {
            case .number:
                if let type = value.numberValue.valueType {
                    values.append(DatabaseValue(name: name, type: type))
                } else {
                    throw JsonResolverError.typeNotSupported(key: name, type: "\(value.type)")
                }
            case .bool:
                values.append(DatabaseValue(name: name, type: .bool(value.boolValue)))
            case .string:
                values.append(DatabaseValue(name: name, type: .string(value.stringValue)))
            default:
                Logger.v(Self.logTag, "json has unsupported type for key `\(name)` \(value.type)")
                throw JsonResolverError.typeNotSupported(key: name, type: "\(value.type)")
            }
        }
        return values
    }
    
    static func validateTypes(incoming: [DatabaseValue], registered: [DatabaseValue]) throws {
        for new in incoming {
            guard let existing = (registered.first{ $0.name == new.name }) else {
                continue
            }
            guard existing.type.typeIsEqual(to: new.type) else {
                Logger.v(Self.logTag, "json has field with incompabile type for key `\(new.name)`; Registered type is \(existing.type.readable) but got \(new.type.readable)")
                throw JsonResolverError.typeMismatch(key: new.name, registered: existing.type.readable, received: new.type.readable)
            }
        }
    }
}

extension NSNumber {
    var type: CFNumberType {
        return CFNumberGetType(self as CFNumber)
    }
}

extension NSNumber {
    var valueType: ValueType? {
        switch type {
        case .sInt8Type, .charType, .sInt16Type, .shortType, .sInt32Type, .longType, .sInt64Type, .longLongType, .intType, .cfIndexType, .nsIntegerType:
            return .int(self.int64Value)
        case .float32Type, .floatType, .float64Type, .doubleType, .cgFloatType:
            return .double(self.doubleValue)
        default:
            return nil
        }
    }
}
