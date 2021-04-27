# iOS Image Server

This is an example of running Hummingbird on iOS. It is a image file server that uses your photo library on your iPhone as source data.

The application has some rudimentary authentication added to ensure you aren't sharing your photo library with everyone on your local network. When you start the app a dialog appears giving you a login key. Go to the IP address of your iPhone in a web browser and enter the key in the dialog. Once the key is entered the server will serve HTML files containing images from your iPhone. You can find your iPhone IP address in Settings -> Wifi. Click on the info button next to the wifi network you are connected to, to view your IP address. Also note the image server will only work when the app is in the foreground.


