# Hummingbird HTML Form

This application demonstrates working with HTML forms. Set the working directory to the local folder, run app and open up a web browser and go to http://localhost:8080. 

The HTML form is generated using the [Mustache](https://github.com/hummingbird-project/swift-mustache) library. A new type `HTML` is added that conforms to `ResponseGenerator`. This generates a response with the `HTML` text contents and a `content-type` header set to `text/html`.

Added a new `RequestDecoder` that checks the header value `content-type` and if it is `application/x-www-form-urlencoded` then decodes request using `URLFormRequestDecoder`. Otherwise returns unsupported media type.

You can run and experiment with the example by building the Dockerfile and running the container.

Alternatively, you can build and run the example from [VSCode](https://www.swift.org/documentation/articles/getting-started-with-vscode-swift.html) or [Xcode](https://developer.apple.com/xcode/).