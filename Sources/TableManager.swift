//
//  TableManager.swift
//
//
//  Created by Tomasz on 11/07/2024.
//

import Foundation
import SQLite

enum TableManagerError: Error {
    case unsupportedDBType
    case invalidIdType
    case objectNotExists(id: Int64)
}

class TableManager {
    let connection: Connection
    let tableName: String
    let table: Table
    private var existingColumns: [DatabaseValue]
    private let idExpression = ExpressionFactory.intExpression("id")
    
    var schema: JSON {
        var dict: [String:String] = [:]
        for column in existingColumns {
            dict[column.name] = column.type.readable
        }
        return JSON(dict)
    }
    
    init(connection: Connection, tableName: String) throws {
        self.connection = connection
        self.tableName = tableName
        self.table = Table(tableName)
        self.existingColumns = try connection.schema.columnDefinitions(table: tableName).map { definition in
            guard let valueType = definition.type.valueType else {
                throw TableManagerError.unsupportedDBType
            }
            return DatabaseValue(name: definition.name, type: valueType)
        }
    }

    private func createTable(for values: [DatabaseValue]) throws {
        try connection.run(table.create(ifNotExists: true) { t in
            t.column(idExpression, primaryKey: .autoincrement)
            for value in values {
                if value.name == "id" { continue }
                switch value.type {
                case .int:
                    t.column(ExpressionFactory.intOptionalExpression(value.name))
                case .string:
                    t.column(ExpressionFactory.stringOptionalExpression(value.name))
                case .double:
                    t.column(ExpressionFactory.doubleOptionalExpression(value.name))
                }
                self.existingColumns.append(DatabaseValue(name: value.name, type: value.type))
            }
        })
        print("Created new table `\(tableName)` with columns: \(self.existingColumns.map { "`\($0.name)`: \($0.type.readable)" })")
    }

    private func alterTableIfNeeded(for values: [DatabaseValue]) throws {
        for value in values {
            if value.name == "id" { continue }
            if self.existingColumns.map({ $0.name }).contains(value.name) {
                continue
            }
            switch value.type {
            case .int:
                try connection.run(table.addColumn(ExpressionFactory.intOptionalExpression(value.name)))
            case .string:
                try connection.run(table.addColumn(ExpressionFactory.stringOptionalExpression(value.name)))
            case .double:
                try connection.run(table.addColumn(ExpressionFactory.doubleOptionalExpression(value.name)))
            }
            print("Extended table `\(tableName)` with column `\(value.name)`: \(value.type.readable)")
            self.existingColumns.append(DatabaseValue(name: value.name, type: value.type))
            
        }
    }
    
    func store(_ json: JSON) throws -> JSON {
        let values = try JsonResolver.resolve(json)
        try JsonResolver.validateTypes(incoming: values, registered: self.existingColumns)
        if self.existingColumns.isEmpty {
            try self.createTable(for: values)
        } else {
            try self.alterTableIfNeeded(for: values)
        }
        var setters: [Setter] = []
        for value in values {
            if value.name == "id" { continue }
            switch value.type {
            case .int(let int):
                setters.append(ExpressionFactory.intOptionalExpression(value.name) <- int)
            case .string(let txt):
                setters.append(ExpressionFactory.stringOptionalExpression(value.name) <- txt)
            case .double(let number):
                setters.append(ExpressionFactory.doubleOptionalExpression(value.name) <- number)
            }
        }
        
        if let id = (values.first { $0.name == "id" }) {
            switch id.type {
            case .int(let number):
                let updatedRows = try connection.run(table.filter(idExpression == number).update(setters))
                guard updatedRows == 1 else {
                    throw TableManagerError.objectNotExists(id: number)
                }
                return json
            default:
                throw TableManagerError.invalidIdType
            }
        } else {
            let id = try connection.run(table.insert(setters))
            var response = json.dictionaryObject
            response?["id"] = id
            return JSON(response ?? [:])
        }
    }
    
    func delete(id: Int64) throws {
        let query = table.filter(idExpression == id)
        guard try connection.run(query.delete()) == 1 else {
            throw TableManagerError.objectNotExists(id: id)
        }
    }
    
    func get(id: Int64) throws -> JSON? {
        let query = table.filter(idExpression == id)
        guard let row = try connection.pluck(query) else {
            return nil
        }
        var dic = [String: Any]()
        for column in existingColumns {
            switch column.type {
            case .string:
                dic[column.name] = row[ExpressionFactory.stringOptionalExpression(column.name)]
            case .int:
                dic[column.name] = row[ExpressionFactory.intOptionalExpression(column.name)]
            case .double:
                dic[column.name] = row[ExpressionFactory.doubleOptionalExpression(column.name)]
            }
        }
        return JSON(dic)
    }
}
