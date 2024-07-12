//
//  String+extension.swift
//
//
//  Created by Tomasz Kucharski on 12/07/2024.
//

import Foundation

extension String {
    var camelCaseToSnakeCase: String {
        var newString = ""
        for character in self {
            if character.isUppercase {
                if !newString.isEmpty {
                    newString.append("_")
                }
            }
            newString.append(character)
        }
        return newString.lowercased()
    }
}
