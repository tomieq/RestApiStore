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

// create or update when id is given in body
server.post[":dbName/data/:tableName"] = { request, _ in
    let source: Source = try request.pathParams.decode()
    let json = try JSON(data: request.body.data)
    guard json.array == nil else {
        return .badRequest(.text("This endpoint accepts only single jsons. If you want create/update multiple objects, use batch operation"))
    }
    let tableManager = try dbManager.getTableManger(db: source.dbName, tableName: source.tableName)
    let response = try tableManager.store(json)
    return .accepted(.jsonString(response))
}
// create or update multiple objects (array) - when id is given in body object will be updated
server.post[":dbName/data/:tableName/batch"] = { request, _ in
    let source: Source = try request.pathParams.decode()
    let json = try JSON(data: request.body.data)
    guard let list = json.array else {
        return .badRequest(.text("This batch endpoint accepts only multiple objects (array)"))
    }
    let tableManager = try dbManager.getTableManger(db: source.dbName, tableName: source.tableName)
    for json in list {
        _ =  try tableManager.store(json)
    }
    return .accepted()
}
// update many resources
server.put[":dbName/data/:tableName"] = { request, _ in
    let source: Source = try request.pathParams.decode()
    let json = try JSON(data: request.body.data)
    let tableManager = try dbManager.getTableManger(db: source.dbName, tableName: source.tableName)
    let filters = request.queryParams.dict
    guard !filters.isEmpty else {
        return .badRequest(.text("Please specify filters"))
    }
    try tableManager.update(json, filter: filters)
    return .accepted()
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
server.middleware.append( { request, header in
    request.disableKeepAlive = true
    Logger.v("📟 Server", "Request \(request.id) \(request.method) \(request.path) from \(request.peerName ?? "")")
    request.onFinished = { id, code, duration in
        Logger.v("📟 Server", "Request \(id) finished with \(code) in \(String(format: "%.3f", duration)) seconds")
    }
    return nil
})
do {
    try server.start(8080)
    Logger.v("📟 Server", "Started at port: \(try server.port())")
    dispatchMain()
} catch {
    print("Error: \(error)")
}
