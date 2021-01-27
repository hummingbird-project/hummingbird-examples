# Hummingbird HTML Form

Uses John Sundells [Plot](https://github.com/JohnSundell/Plot) library to generate the HTML.

HTML type from Plot has been extended to conform to `HBResponseGenerator` so it can be used as a return type from route handlers.

Added a new `HBRequestDecoder` that checks the header value `content-type` and if it is `application/x-www-form-urlencoded` then decodes request using `URLEncodedFormDecoder`. Otherwise returns unsupported media type.
