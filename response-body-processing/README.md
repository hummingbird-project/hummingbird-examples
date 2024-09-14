# Echo with SHA256 Digest using ResponseBodyWriter

This is an example demostrating how you can process Response bodies in middleware using a type conforming to `ResponseBodyWriter`. The server has one endpoint `/echo` which will echo the body of the request back in its response. The response will also include in the response the SHA256 of the data being sent back as a trailing header.

You can test the sample as follows:

```sh
curl localhost:8080/echo -i -d"Hello world"
```

It should respond with:

```
HTTP/1.1 200 OK
Content-Type: application/x-www-form-urlencoded
Date: Fri, 23 Aug 2024 12:05:57 GMT
Server: ResponseBodyProcessing
transfer-encoding: chunked

Hello worldDigest: sha256=64ec88ca00b268e5ba1a35678a1b5316d212f4f366b2477232534a8aeca37f3c
```