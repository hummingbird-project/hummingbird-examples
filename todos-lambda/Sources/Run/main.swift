//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import App
import AWSLambdaEvents
import AWSLambdaRuntime
import HummingbirdFoundation
import HummingbirdLambda

public typealias AppHandler = HBLambdaHandler<AppLambda>

public struct AppLambda: HBLambda {
    public typealias In = APIGateway.Request
    public typealias Out = APIGateway.Response

    public init(_ app: HBApplication) throws {
        try app.configure()
    }
}

Lambda.run { context in
    return try AppHandler(context: context)
}
