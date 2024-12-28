# Server Send Events

Example demonstrating how to setup a route returning Server Sent Events.

The application has one route. `GET /events`. If you call this then every other request sent to the server will be reported back to this route as a server sent event.

