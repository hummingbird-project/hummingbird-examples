# Example Async/Await File Upload

Demonstrating file uploads using the async/await APIs of Hummingbird.

This demo may be useful for organziations that handle secret / sensitive data or otherwise do not want to rely on third party object storage vendors.

## Crucial Requirements

- The server must stream HTTP requests. Loading an entire request into memory is not feasible when there are many users uploading at once.
- The request should be able to determine its filename. Use the `File-Name` header to assign a file name.
- In this example, we allow arbitrary uploads without a `File-Name` header and substitute a UUID instead.
- In this example, we configure the route’s ability to overwrite an existing filename with the same filename. Developers should consider abstracting filenames from users entirely. A good practice is to assign UUID based filenames and store associated metadata in a database.

Also noteworthy is that we’ve updaed the Application.configure

## Routes 

- POST /upload: Uploads bytes. If the `File-Name` header is set, then that string will be used as the file name, otherwise a UUID will be used instead

This example comes with a [PAW](https://paw.cloud/) file you can use.
