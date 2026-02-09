# Hummingbird Websocket chat 

Application demonstrating how to use [web sockets](https://github.com/hummingbird-project/hummingbird-websocket) with Hummingbird 2.

Run the application and then using a web browser go to http://localhost:8080/?username=Adam&channel=Hummingbird

Open another web browser page to create a second connection. Change the "username" query parameter and chat between the two pages. If you change the "channel" query parameter you will start a different chat channel.

The app uses Valkey to store the chat history so you need a running copy of Valkey. The example comes with a docker-compose file to bring up a Valkey server

```
docker-compose up
```

Because this sample serves a web page, you will need to make sure you have set the working directory to the root folder of the example before running. 
