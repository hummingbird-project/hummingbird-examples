# iOS Image Server

This is an example of running Hummingbird on iOS. It is a image file server that uses the photo library on your iPhone as source data.

The application has some rudimentary authentication added to ensure you aren't sharing your photo library with everyone on your local network. When you start the app an alert appears giving you a login key. Enter the IP address of your iPhone in a web browser and in the resultant form enter the login key. If the key is correct you will be forwarded to the photo library website. You can find your iPhone IP address in Settings -> Wifi. Click on the info button next to the wifi network you are connected to, to view your IP address. Also note the image server will only work when the app is in the foreground.

This app makes use of a number of hummingbird features.
- It includes a custom `HBRequestDecoder` for decoding url encoded form data from the login page.
- It includes custom `HBResponseGenerators` for adding the correct `content-type` headers for HTML and Jpeg images.
- The web pages are generated using `HummingbirdMustache`.
- And the routes accessing image data are protected with a custom `HBMiddleware` that checks for a correct `token` cookie
