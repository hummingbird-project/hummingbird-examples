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

set -eu

export AWS_PROFILE=opticalaberration-admin_dev

here=$(dirname $0)
# Lambda Function name
function_name=TodosBackend
executable_name=HummingbirdTodosLambda
policy_name="${function_name}-lamba-policy"
role_name="${function_name}-lamba-role"

# does function already exist
if [ -n "$(aws lambda list-functions --output json --query 'Functions[*].FunctionName' | grep -w "$function_name")" ]; then
    # function exists so just need to update it
    echo "-------------------------------------------------------------------------"
    echo "updating lambda \"$function_name\""
    echo "-------------------------------------------------------------------------"
    aws lambda update-function-code --function "$function_name" --zip-file fileb://.build/lambda/"$executable_name"/lambda.zip

else
    # function does not exist need to create role to run it
    echo "-------------------------------------------------------------------------"
    echo "creating role \"$role_name\""
    echo "-------------------------------------------------------------------------"
    assume_role_policy='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["sts:AssumeRole"],"Principal":{"Service":["lambda.amazonaws.com"]}}]}'
    iam_role_arn=$(aws iam create-role --role-name "$role_name" --assume-role-policy-document "$assume_role_policy" --output text --query "Role.Arn")
    aws iam put-role-policy --role-name "$role_name" --policy-name "$policy_name" --policy-document file://$here/policy.json
    # create lambda
    echo "-------------------------------------------------------------------------"
    echo "creating lambda \"$function_name\""
    echo "-------------------------------------------------------------------------"
    aws lambda create-function --function "$function_name" --role "$iam_role_arn" --runtime provided --memory-size 192 --timeout 20 --handler "$function_name" --zip-file fileb://.build/lambda/"$executable_name"/lambda.zip
fi

