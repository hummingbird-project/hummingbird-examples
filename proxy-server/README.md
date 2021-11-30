# Proxy Server

Demonstrating how to use `Hummingbird` and `AsyncHTTPClient` to build a HTTP Proxy server. 

This is a fairly simple app which forwards HTTP requests to the proxy server onto another server. The forwarding of requests is done by the middleware `HBProxyServerMiddleware`.  

There is still some complexity in that the server streams the request body and response body to avoid having to allocate large buffers. The response streaming needs a `HTTPClientResponseDelegate` to stream the responses from `AsyncHTTPClient`. Once the delegate has received the HTTP head of the response we succeed a promise to pass back a `HBHTTPResponse` which holds this HTTP head and a `ByteBuffer` streamer. The delegate will continue to feed any `ByteBuffers` it receives to this streamer. Meanwhile Hummingbird server will consume the buffers and pass them back to the original client.

By default the proxy server will send requests to `localhost:8080` so you can run this with most of the other hummingbird samples and use the proxy server address `localhost:8081` to access them. If you want to target a different server add the command line `--target server-address`.
