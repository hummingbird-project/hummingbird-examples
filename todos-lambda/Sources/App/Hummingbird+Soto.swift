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

import Hummingbird
import SotoDynamoDB

extension HBApplication {
    public struct AWS {
        public var client: AWSClient {
            get { self.application.extensions.get(\.aws.client) }
            nonmutating set {
                application.extensions.set(\.aws.client, value: newValue) { client in
                    try client.syncShutdown()
                }
            }
        }

        public var dynamoDB: DynamoDB {
            get { self.application.extensions.get(\.aws.dynamoDB) }
            nonmutating set { application.extensions.set(\.aws.dynamoDB, value: newValue) }
        }

        let application: HBApplication
    }

    public var aws: AWS { return .init(application: self) }
}

extension HBRequest {
    public struct AWS {
        var client: AWSClient { self.application.aws.client }
        var dynamoDB: DynamoDB { self.application.aws.dynamoDB }
        let application: HBApplication
    }

    public var aws: AWS { return .init(application: self.application) }
}
