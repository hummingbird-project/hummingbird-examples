import Foundation
import FluentSQLiteDriver
import Hummingbird
import HummingbirdFluent
import HummingbirdFoundation

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
    app.router
        .group("todos")
        .get(use: todoController.list)
        .put(use: todoController.create)
        .get(":id", use: todoController.get)
        .put(":id", use: todoController.update)
        .delete(":id", use: todoController.delete)

    app.start()
    app.wait()
}
