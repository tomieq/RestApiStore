import Foundation
import Swifter
import Dispatch
import SQLite

let dbManager = DatabaseManager()

struct Search: Codable {
    let dbName: String
    let tableName: String
    let id: Int64
}

struct Source: Codable {
    let dbName: String
    let tableName: String
}

let server = HttpServer()
server.get[":dbName/data/:tableName/:id"] = { request, _ in
    let search: Search = try request.pathParams.decode()
    let tableManager = try dbManager.getTableManger(db: search.dbName, tableName: search.tableName)
    guard let json = try tableManager.get(id: search.id) else {
        return .notFound()
    }
    return .ok(.jsonString(json))
}

server.post[":dbName/data/:tableName"] = { request, _ in
    let source: Source = try request.pathParams.decode()
    let json = try JSON(data: request.body.data)
    let tableManager = try dbManager.getTableManger(db: source.dbName, tableName: source.tableName)
    let response = try tableManager.store(json)
    return .created(.jsonString(response))
}

server.delete[":dbName/data/:tableName/:id"] = { request, _ in
    let search: Search = try request.pathParams.decode()
    let tableManager = try dbManager.getTableManger(db: search.dbName, tableName: search.tableName)
    try tableManager.delete(id: search.id)
    return .accepted()
}

try server.start(8080)
dispatchMain()