import App
import AWSLambdaRuntime

Lambda.run { context in
    return AppHandler(context: context)
}
