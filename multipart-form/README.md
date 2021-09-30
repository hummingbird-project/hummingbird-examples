# Multipart Form decoding

Application demonstrating working with HTML forms using multipart form data. Set the working directory to the local folder, run app and open up a web browser and go to localhost:8080.

This example uses the MultipartKit package for decoding the multipart form data sent by the web browser. The HTML form is generated using the [HummingbirdMustache](https://github.com/hummingbird-project/hummingbird-mustache) library. A new type `HTML` is added that conforms to `HBResponseGenerator`. This generates a response with the `HTML` text contents and a `content-type` header set to `text/html`.

Added a new `HBRequestDecoder` that checks the header value `content-type` and if its media type is `.multipartForm` then decodes request using `FormDataDecoder` from the MultipartKit package. Otherwise returns unsupported media type.
