# S3 File Provider

Example of using FileMiddleware to serve and cache files stored on S3.

By providing a type conforming to `FileProvider` to `FileMiddleware` we can serve files from other sources than the local disk. This example creates two file providers, one that serves files from an S3 bucket and one that takes a base FileProvider and caches its results in memory. These two are combined to create a FileProvider that sources files from S3 and caches them in memory.

The example needs two environment variables: 
- `s3_file_region`: Defines the AWS region to use eg us-east-1
- `s3_file_bucket`: The name of the bucket to serve files from

There is an optional environment variable:
- `s3_file_path`: Prefix to add when generating S3 file path.

When you run the app, as long as your AWS credentials allow it, you can go to a web browser and view the contents of your S3 bucket. 

NB The S3 file provider does not recognise folders, so you will not get the automatic re-directing to `index.html` in folders.