# Example Async/Await File Upload using S3 as backing storage

Demonstrating file uploads to S3 using Hummingbird and [Soto](https://github.com/soto-project/soto).

This example requires you have an [AWS](https://aws.amazon.com) account with access to S3. You should setup an S3 bucket to save your files to. Before running the application set the "s3_upload_bucket" environment variable to the name of your S3 bucket. You can also use the "s3_upload_folder" environment variable to control what folder inside your S3 bucket the files will be saved to.

## Requirements

- The server must stream HTTP requests. Loading an entire request into memory is not feasible when there are many users uploading at once.
- The request should be able to determine its filename. Use the `File-Name` header to assign a file name.
- In this example, we allow arbitrary uploads without a `File-Name` header and substitute a UUID instead.

## Routes 

- POST /files - Uploads request payload to S3. If the `File-Name` header is set, then that string will be used as the file name, otherwise a UUID will be used instead
- GET /files/:string - Downloads a file from S3 using filename `:string` if it exists.

