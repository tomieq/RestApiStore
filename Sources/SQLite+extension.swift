//
//  SQLite+extension.swift
//
//
//  Created by Tomasz on 11/07/2024.
//

import Foundation
import SQLite

extension SQLite.ColumnDefinition.Affinity {
    var valueType: ValueType? {
        switch self {
        case .INTEGER, .NUMERIC:
            return .int(0)
        case .REAL:
            return .double(0)
        case .TEXT:
            return .string("")
        default:
            return nil
        }
    }
}
