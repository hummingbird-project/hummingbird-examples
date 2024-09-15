# Hello

Simple app demonstrating the [Jobs](https://github.com/hummingbird-project/swift-jobs) framework for job queues.

The app uses redis to store the job queue so you need a copy of redis running

```sh
docker run -p 6379:6379 redis
```

This demonstrates an HTTP server writing to a job queue. If another version of the app is running with the command line argument `--process-jobs` it will pick up these jobs and execute them. The example demonstrates how to offload work to another server.
