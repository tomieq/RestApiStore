//
//  DatabaseManager.swift
//
//
//  Created by Tomasz on 11/07/2024.
//

import Foundation
import SQLite

class DatabaseManager {
    private let logTag = "🛢️ DatabaseManager"
    private var connections: [String: Connection] = [:]
    private var tableManagers: [String: TableManager] = [:]
    private let accessQueue = DispatchQueue(label: "store.database", qos: .userInitiated, attributes: .concurrent)
    
    func getTableManger(db: String, tableName: String) throws -> TableManager {
        try accessQueue.sync(flags: .barrier) {
            let key = "\(db).\(tableName)"
            if let tableManager = tableManagers[key] {
                return tableManager
            }
            let tableManager = try TableManager(connection: getConnection(db: db), tableName: tableName)
            Logger.v(logTag, "Created new table `\(tableName)` in database `\(db)`")
            tableManagers[key] = tableManager
            return tableManager
        }
    }
    
    private func getConnection(db: String) throws -> Connection {
        if let connection = self.connections[db] {
            return connection
        }
        let path = "\(FileManager.default.currentDirectoryPath)/\(db).db"
        let connection = try Connection(path)
        self.connections[db] = connection
        Logger.v(logTag, "Opened new database `\(db)` in file: \(path)")
        return connection
    }
}
