//
//  ExpressionFactory.swift
//
//
//  Created by Tomasz on 11/07/2024.
//

import Foundation
import SQLite

enum ExpressionFactory {
    static func intExpression(_ name: String) -> Expression<Int64> {
        Expression<Int64>(name)
    }
    
    static func stringExpression(_ name: String) -> Expression<String> {
        Expression<String>(name)
    }
    
    static func intOptionalExpression(_ name: String) -> Expression<Int64?> {
        Expression<Int64?>(name)
    }
    
    static func stringOptionalExpression(_ name: String) -> Expression<String?> {
        Expression<String?>(name)
    }
    
    static func doubleOptionalExpression(_ name: String) -> Expression<Double?> {
        Expression<Double?>(name)
    }
}
