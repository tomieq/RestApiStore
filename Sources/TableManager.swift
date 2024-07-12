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
    case unknownFilterKey(String)
}

class TableManager {
    let connection: Connection
    let tableName: String
    let tableWithData: Table
    let tableWithMetadata: Table
    //let table: Table
    private let logTag = "💾 TableManager"
    private let accessQueue: DispatchQueue
    private var existingColumns: [DatabaseValue] = []
    private let idExpression = ExpressionFactory.intExpression("id")
    private var tableExists: Bool {
        !self.existingColumns.isEmpty
    }
    
    var schema: JSON {
        var dict: [String:String] = [:]
        for column in existingColumns {
            dict[column.name] = column.type.readable
        }
        return JSON(dict)
    }
    
    init(connection: Connection, tableName: String) throws {
        self.connection = connection
        self.tableName = tableName.camelCaseToSnakeCase
        self.tableWithData = Table(self.tableName)
        self.tableWithMetadata = Table(self.tableName + "_column_definitions")
        self.accessQueue = DispatchQueue(label: "store.table.\(self.tableName)", qos: .userInitiated, attributes: .concurrent)
        try? self.loadMetadata()
    }
    
    private func createMetadataTable() throws {
        try connection.run(tableWithMetadata.create(ifNotExists: true) { t in
            t.column(ExpressionFactory.stringExpression("name"))
            t.column(ExpressionFactory.stringExpression("value_type"))
        })
    }

    private func columnAdded(_ column: DatabaseValue) throws {
        try connection.run(tableWithMetadata.insert(
            ExpressionFactory.stringExpression("name") <- column.name,
            ExpressionFactory.stringExpression("value_type") <- column.type.readable
        ))
        self.existingColumns.append(DatabaseValue(name: column.name, type: column.type))
    }
    
    private func loadMetadata() throws {
        for row in try connection.prepare(tableWithMetadata) {
            let name = row[ExpressionFactory.stringExpression("name")]
            let type = row[ExpressionFactory.stringExpression("value_type")]
            if let valueType = ValueType.make(from: type) {
                self.existingColumns.append(DatabaseValue(name: name, type: valueType))
            } else {
                Logger.v(self.logTag, "Existing table `\(tableName)` contains unsupported data type: \(type)")
                throw TableManagerError.unsupportedDBType
            }
        }
    }

    private func createTable(for values: [DatabaseValue]) throws {
        try connection.run(tableWithData.create(ifNotExists: true) { t in
            t.column(idExpression, primaryKey: .autoincrement)
            try? columnAdded(DatabaseValue(name: "id", type: .int(0)))
            for value in values {
                if value.name == "id" { continue }
                switch value.type {
                case .int:
                    t.column(ExpressionFactory.intOptionalExpression(value.name))
                case .string:
                    t.column(ExpressionFactory.stringOptionalExpression(value.name))
                case .double:
                    t.column(ExpressionFactory.doubleOptionalExpression(value.name))
                case .bool:
                    t.column(ExpressionFactory.boolOptionalExpression(value.name))
                }
                try? self.columnAdded(DatabaseValue(name: value.name, type: value.type))
            }
        })
        Logger.v(self.logTag, "Created new table `\(tableName)` with columns: \(self.existingColumns.map { "`\($0.name)`: \($0.type.readable)" })")
    }

    private func alterTableIfNeeded(for values: [DatabaseValue]) throws {
        for value in values {
            if value.name == "id" { continue }
            if self.existingColumns.map({ $0.name }).contains(value.name) {
                continue
            }
            switch value.type {
            case .int:
                try connection.run(tableWithData.addColumn(ExpressionFactory.intOptionalExpression(value.name)))
            case .string:
                try connection.run(tableWithData.addColumn(ExpressionFactory.stringOptionalExpression(value.name)))
            case .double:
                try connection.run(tableWithData.addColumn(ExpressionFactory.doubleOptionalExpression(value.name)))
            case .bool:
                try connection.run(tableWithData.addColumn(ExpressionFactory.boolOptionalExpression(value.name)))
            }
            Logger.v(self.logTag, "Extended table `\(tableName)` with column `\(value.name)`: \(value.type.readable)")
            try columnAdded(DatabaseValue(name: value.name, type: value.type))
        }
    }
    
    func store(_ json: JSON) throws -> JSON {
        try accessQueue.sync(flags: .barrier) {
            let values = try JsonResolver.resolve(json)
            try JsonResolver.validateTypes(incoming: values, registered: self.existingColumns)
            if self.existingColumns.isEmpty {
                try self.createMetadataTable()
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
                case .bool(let flag):
                    setters.append(ExpressionFactory.boolOptionalExpression(value.name) <- flag)
                }
            }
            
            if let id = (values.first { $0.name == "id" }) {
                switch id.type {
                case .int(let number):
                    let updatedRows = try connection.run(tableWithData.filter(idExpression == number).update(setters))
                    guard updatedRows == 1 else {
                        Logger.v(self.logTag, "Tried to update non existing object id: \(number) in table `\(tableName)`")
                        throw TableManagerError.objectNotExists(id: number)
                    }
                    Logger.v(self.logTag, "Updated object with id: \(number) in table `\(tableName)`")
                    return json
                default:
                    Logger.v(self.logTag, "Tried to update object with invalid type of ID: \(id.type.readable) in table `\(tableName)`")
                    throw TableManagerError.invalidIdType
                }
            } else {
                let id = try connection.run(tableWithData.insert(setters))
                Logger.v(self.logTag, "Created object with id: \(id) in table `\(tableName)`")
                var response = json.dictionaryObject
                response?["id"] = id
                return JSON(response ?? [:])
            }
        }
    }
    
    func update(_ json: JSON, filter: [String:String]) throws {
        try accessQueue.sync(flags: .barrier) {
            let values = try JsonResolver.resolve(json)
            try JsonResolver.validateTypes(incoming: values, registered: self.existingColumns)
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
                case .bool(let flag):
                    setters.append(ExpressionFactory.boolOptionalExpression(value.name) <- flag)
                }
            }
            
            var query = tableWithData
            for (filterKey, filterValue) in filter {
                guard let column = (self.existingColumns.first {$0.name == filterKey}) else {
                    throw TableManagerError.unknownFilterKey(filterKey)
                }
                switch column.type {
                case .string:
                    query = query.filter(ExpressionFactory.stringOptionalExpression(column.name) == filterValue)
                case .int:
                    query = query.filter(ExpressionFactory.intOptionalExpression(column.name) == Int64(filterValue))
                case .double:
                    query = query.filter(ExpressionFactory.doubleOptionalExpression(column.name) == Double(filterValue))
                case .bool:
                    query = query.filter(ExpressionFactory.boolOptionalExpression(column.name) == Bool(filterValue))
                }
            }
            let updatedRows = try connection.run(query.update(setters))
            Logger.v(self.logTag, "Updated \(updatedRows) objects with filter \(filter.map{ "\($0.key) = \($0.value)"}) in table `\(tableName)`")
        }
    }

    func delete(id: Int64) throws {
        guard tableExists else { return }
        try accessQueue.sync(flags: .barrier) {
            let query = tableWithData.filter(idExpression == id)
            guard try connection.run(query.delete()) == 1 else {
                Logger.v(self.logTag, "Couldn't delete object with id: \(id) from table `\(tableName)`")
                throw TableManagerError.objectNotExists(id: id)
            }
            Logger.v(self.logTag, "Deleted object with id: \(id) from table `\(tableName)`")
        }
    }

    func deleteMany(filter: [String:String]) throws {
        guard tableExists else { return }
        try accessQueue.sync(flags: .barrier) {
            var query = tableWithData
            for (filterKey, filterValue) in filter {
                guard let column = (self.existingColumns.first {$0.name == filterKey}) else {
                    throw TableManagerError.unknownFilterKey(filterKey)
                }
                switch column.type {
                case .string:
                    query = query.filter(ExpressionFactory.stringOptionalExpression(column.name) == filterValue)
                case .int:
                    query = query.filter(ExpressionFactory.intOptionalExpression(column.name) == Int64(filterValue))
                case .double:
                    query = query.filter(ExpressionFactory.doubleOptionalExpression(column.name) == Double(filterValue))
                case .bool:
                    query = query.filter(ExpressionFactory.boolOptionalExpression(column.name) == Bool(filterValue))
                }
            }
            let amount = try connection.run(query.delete())
            Logger.v(self.logTag, "Deleted \(amount) objects with filter: \(filter.map{ "\($0.key) = \($0.value)"}) from table `\(tableName)`")
        }
    }
    
    func get(id: Int64) throws -> JSON? {
        guard tableExists else { return nil }
        return try accessQueue.sync {
            let query = tableWithData.filter(idExpression == id)
            guard let row = try connection.pluck(query) else {
                Logger.v(logTag, "Could not find object with id: \(id) in table `\(tableName)`")
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
                case .bool:
                    dic[column.name] = row[ExpressionFactory.boolOptionalExpression(column.name)]
                }
            }
            Logger.v(logTag, "Returned object with id: \(id) from table `\(tableName)`")
            return JSON(dic)
        }
    }
    
    func getMany(filter: [String:String]? = nil) throws -> JSON? {
        guard tableExists else { return nil }
        return try accessQueue.sync {
            var query = tableWithData
            for (filterKey, filterValue) in filter ?? [:] {
                guard let column = (self.existingColumns.first {$0.name == filterKey}) else {
                    throw TableManagerError.unknownFilterKey(filterKey)
                }
                switch column.type {
                case .string:
                    query = query.filter(ExpressionFactory.stringOptionalExpression(column.name) == filterValue)
                case .int:
                    query = query.filter(ExpressionFactory.intOptionalExpression(column.name) == Int64(filterValue))
                case .double:
                    query = query.filter(ExpressionFactory.doubleOptionalExpression(column.name) == Double(filterValue))
                case .bool:
                    query = query.filter(ExpressionFactory.boolOptionalExpression(column.name) == Bool(filterValue))
                }
            }
            var dictionaries: [[String: Any]] = []
            for row in try connection.prepare(query) {
                var dict = [String: Any]()
                for column in existingColumns {
                    switch column.type {
                    case .string:
                        dict[column.name] = row[ExpressionFactory.stringOptionalExpression(column.name)]
                    case .int:
                        dict[column.name] = row[ExpressionFactory.intOptionalExpression(column.name)]
                    case .double:
                        dict[column.name] = row[ExpressionFactory.doubleOptionalExpression(column.name)]
                    case .bool:
                        dict[column.name] = row[ExpressionFactory.boolOptionalExpression(column.name)]
                    }
                }
                dictionaries.append(dict)
            }
            Logger.v(logTag, "Returned \(dictionaries.count) objects with filter: \(filter?.map{ "\($0.key) = \($0.value)"} ?? []) from table `\(tableName)`")
            return JSON(dictionaries)
        }
    }
}
