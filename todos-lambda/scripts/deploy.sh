#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftAWSLambdaRuntime open source project
##
## Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

here=$(dirname "$0")

if [ ! $(which sam) ]; then
    echo "The deploy script requires AWS SAM."
    echo "More information about AWS SAM and installation instructions can be found at https://aws.amazon.com/serverless/sam/"
    exit -1
fi

cd "$here"/..
sam deploy --stack-name hb-todos-lambda --resolve-s3 --template scripts/sam.yml $@
