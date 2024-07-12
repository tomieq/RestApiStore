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

server.get[":dbName/data/:tableName"] = { request, _ in
    let source: Source = try request.pathParams.decode()
    let tableManager = try dbManager.getTableManger(db: source.dbName, tableName: source.tableName)
    guard let json = try tableManager.getMany(filter: request.queryParams.dict) else {
        return .notFound()
    }
    return .ok(.jsonString(json))
}
server.get[":dbName/data/:tableName/:id"] = { request, _ in
    let search: Search = try request.pathParams.decode()
    let tableManager = try dbManager.getTableManger(db: search.dbName, tableName: search.tableName)
    guard let json = try tableManager.get(id: search.id) else {
        return .notFound()
    }
    return .ok(.jsonString(json))
}

server.get[":dbName/schema/:tableName"] = { request, _ in
    let source: Source = try request.pathParams.decode()
    let tableManager = try dbManager.getTableManger(db: source.dbName, tableName: source.tableName)
    return .ok(.jsonString(tableManager.schema))
}

server.post[":dbName/data/:tableName"] = { request, _ in
    let source: Source = try request.pathParams.decode()
    let json = try JSON(data: request.body.data)
    let tableManager = try dbManager.getTableManger(db: source.dbName, tableName: source.tableName)
    let response = try tableManager.store(json)
    return .accepted(.jsonString(response))
}

server.delete[":dbName/data/:tableName/:id"] = { request, _ in
    let search: Search = try request.pathParams.decode()
    let tableManager = try dbManager.getTableManger(db: search.dbName, tableName: search.tableName)
    try tableManager.delete(id: search.id)
    return .accepted()
}

server.delete[":dbName/data/:tableName"] = { request, _ in
    let source: Source = try request.pathParams.decode()
    let tableManager = try dbManager.getTableManger(db: source.dbName, tableName: source.tableName)
    let filters = request.queryParams.dict
    guard !filters.isEmpty else {
        return .badRequest(.text("Please specify filters"))
    }
    try tableManager.deleteMany(filter: filters)
    return .accepted()
}
do {
    try server.start(8080)
    Logger.v("Server", "Started at port: \(try server.port())")
    dispatchMain()
} catch {
    print("Error: \(error)")
}
