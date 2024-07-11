//
//  DatabaseManager.swift
//
//
//  Created by Tomasz on 11/07/2024.
//

import Foundation
import SQLite

class DatabaseManager {
    private var connections: [String: Connection] = [:]
    private var tableManagers: [String: TableManager] = [:]
    
    func getTableManger(db: String, tableName: String) throws -> TableManager {
        let key = "\(db).\(tableName)"
        if let tableManager = tableManagers[key] {
            return tableManager
        }
        let tableManager = try TableManager(connection: getConnection(db: db), tableName: tableName)
        tableManagers[key] = tableManager
        return tableManager
    }
    
    private func getConnection(db: String) throws -> Connection {
        if let connection = self.connections[db] {
            return connection
        }
        let connection = try Connection("\(FileManager.default.currentDirectoryPath)/\(db).db")
        self.connections[db] = connection
        return connection
    }
}
