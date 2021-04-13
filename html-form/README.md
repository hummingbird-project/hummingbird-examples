# Hummingbird HTML Form

Application demonstrating working with HTML forms. Run app and open up a web browser and go to localhost:8080. 

The HTML form is generated using the [HummingbirdMustache](https://github.com/hummingbird-project/hummingbird-mustache) library. A new type `HTML` is added that conforms to `HBResponseGenerator`. This generates a response with the `HTML` text contents and a `content-type` header set to `text/html`.

Added a new `HBRequestDecoder` that checks the header value `content-type` and if it is `application/x-www-form-urlencoded` then decodes request using `URLEncodedFormDecoder`. Otherwise returns unsupported media type.
