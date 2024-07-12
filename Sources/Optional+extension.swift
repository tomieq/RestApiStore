//
//  Optional+extension.swift
//
//
//  Created by Tomasz Kucharski on 12/07/2024.
//

import Foundation

extension Optional where Wrapped: CustomStringConvertible {
    public var readable: String {
        switch self {
        case .some(let value):
            return value.description
        case .none:
            return "nil"
        }
    }
}
