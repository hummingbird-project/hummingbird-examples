# Hummingbird HTML Form

This application demonstrates working with HTML forms. Set the working directory to the local folder, run app and open up a web browser and go to http://localhost:8080. 

The HTML form is generated using the [Mustache](https://github.com/hummingbird-project/swift-mustache) library. A new type `HTML` is added that conforms to `ResponseGenerator`. This generates a response with the `HTML` text contents and a `content-type` header set to `text/html`.

Added a new `RequestDecoder` that checks the header value `content-type` and if it is `application/x-www-form-urlencoded` then decodes request using `URLFormRequestDecoder`. Otherwise returns unsupported media type.