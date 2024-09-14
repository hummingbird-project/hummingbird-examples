# Proxy Server

Demonstrates how to use `Hummingbird` and `AsyncHTTPClient` to build a HTTP Proxy server. 

This is a fairly simple app which forwards HTTP requests to another server. The forwarding of requests is done by the middleware `ProxyServerMiddleware`.  

When the proxy server receives a request it will create a new `HTTPClientRequest` object for the AsyncHTTPClient library, and set the URL to the target server. It will then stream the request body to the target server, ensuring backpressure is respected without significant memory usage.

The HTTP response that is received from the target server is received in a streaming fashion by AsyncHTTPClient, which also supports backpressure. The response is then streamed back to the original client by Hummingbird.

By default the proxy server will send requests to `localhost:8080` so you can run this with most of the other hummingbird samples and use the proxy server address `localhost:8081` to access them. If you want to target a different server add the command line `--target server-address`.
