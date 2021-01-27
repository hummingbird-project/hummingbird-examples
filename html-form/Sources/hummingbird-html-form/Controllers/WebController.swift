import Plot
import Hummingbird

struct WebController {
    var head: Node<HTML.DocumentContext> {
        .head(
            .title("My website")
        )
    }

    func input(request: HBRequest) -> HTML {
        return HTML(
            self.head,
            .body(
                .div(
                    .h1("Please enter your details"),
                    .form(
                        .action("/index.html"),
                        .method(.post),
                        .label(.for("name"), .text("Name")),
                        .br(),
                        .input(.type(.text), .id("name"), .name("name")),
                        .br(),
                        .label(.for("age"), .text("Age")),
                        .br(),
                        .input(.type(.text), .id("age"), .name("age")),
                        .br(),
                        .input(.type(.submit), .value("Submit"))
                    )
                )
            )
        )
    }

    func post(request: HBRequest) throws -> HTML {
        if let user = try? request.decode(as: User.self) {
            return HTML(
                self.head,
                .body(
                    .div(
                        .h1("You entered"),
                        .ul(
                            .li(.text("Name: \(user.name)")),
                            .li(.text("Age: \(user.age)"))
                        )
                    )
                )
            )
        } else {
            return HTML(
                self.head,
                .body(
                    .div(
                        .h1("You entered invalid data")
                    )
                )
            )
        }
    }
}
