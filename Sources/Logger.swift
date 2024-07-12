//
//  Logger.swift
//
//
//  Created by Tomasz Kucharski on 12/07/2024.
//

import Foundation

enum Logger {
    static func v(_ label: String?, _ message: CustomStringConvertible) {
        print("\(Date().readable) [\(label.readable)] \(message)")
    }
}
