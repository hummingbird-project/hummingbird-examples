# Hummingbird HTML Form

Application demonstrating working with HTML forms. Run app and open up a web browser and go to localhost:8080. 

The HTML form is generated using John Sundell's [Plot](https://github.com/JohnSundell/Plot) library. `HTML` type from Plot has been extended to conform to `HBResponseGenerator` so it can be used as a return type from route handlers.

Added a new `HBRequestDecoder` that checks the header value `content-type` and if it is `application/x-www-form-urlencoded` then decodes request using `URLEncodedFormDecoder`. Otherwise returns unsupported media type.
