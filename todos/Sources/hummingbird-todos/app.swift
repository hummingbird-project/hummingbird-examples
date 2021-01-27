import Foundation
import FluentSQLiteDriver
import Hummingbird
import HummingbirdFluent
import HummingbirdJSON

func runApp(_ arguments: HummingbirdArguments) throws {
    let app = HBApplication(configuration: .init(address: .hostname(arguments.hostname, port: arguments.port)))
    // set encoder and decoder
    app.encoder = JSONEncoder()
    app.decoder = JSONDecoder()
    
    // add Fluent
    app.addFluent()
    // add sqlite database
    app.fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    // add migrations
    app.fluent.migrations.add(CreateTodo())
    // migrate
    if arguments.migrate {
        try app.fluent.migrate().wait()
    }

    app.router.get("/") { _ in
        return "Hello"
    }
    let todoController = TodoController()
    app.router.get("todos", use: todoController.list)
    app.router.put("todos", use: todoController.create)
    app.router.get("todos/:id", use: todoController.get)
    app.router.put("todos/:id", use: todoController.update)
    app.router.delete("todos/:id", use: todoController.delete)

    app.start()
    app.wait()
}
