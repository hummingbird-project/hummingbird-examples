# Multipart Form decoding

Application demonstrating working with HTML forms using multipart form data. Set the working directory to the local folder, run app and open up a web browser and go to localhost:8080.

This example uses the [MultipartKit](https://github.com/vapor/multipart-kit) package for decoding the multipart form data sent by the web browser. The HTML form is generated using the [Mustache](https://github.com/hummingbird-project/swift-mustache) library. A new type `HTML` is added that conforms to `ResponseGenerator`. This generates a response with the `HTML` text contents and a `content-type` header set to `text/html`.

It also adds a new `RequestDecoder` called `MultipartRequestDecoder` that checks the header value `content-type` and if its media type is `.multipartForm` then decodes request using `FormDataDecoder` from the MultipartKit package. Other content types will result in the app returning "unsupported media type".
