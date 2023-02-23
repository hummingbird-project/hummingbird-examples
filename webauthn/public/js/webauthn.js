//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// WebAuthn Javascript functions

/**
 * Register User
 * @param {*} username 
 * @param {*} fullname 
 */
async function register(username, fullname) {
    try {
        let data = {
            "name": username,
            "displayName": fullname
        }
        const response = await asyncAjax({
            url: '/api/beginregister',
            type: 'POST',
            contentType: 'application/json',
            data: JSON.stringify(data),
            dataType: 'json',
            processData: false
        });
        const publicKeyCredentialCreationOptions = createPublicKeyCredentialCreationOptionsFromServerResponse(response);
        const result = await navigator.credentials.create({publicKey: publicKeyCredentialCreationOptions});
        const registrationCredential = createRegistrationCredentialForServer(result);
        await asyncAjax({
            url: '/api/finishregister',
            type: 'POST',
            contentType: 'application/json',
            data: JSON.stringify(registrationCredential),
            dataType: 'text',
            processData: false
        })
        alert("Registered user");
    } catch(error) {
        alert(`Login failed: ${error.message}`)
    }
}

/**
 * Login user
 */
async function login() {
    try {
        const response = await asyncAjax({
            url: '/api/login',
            type: 'GET',
            dataType: 'json'
        })
        const publicKeyCredentialRequestOptions = createPublicKeyCredentialRequestOptionsFromServerResponse(response)
        const result = await navigator.credentials.get({
            publicKey: publicKeyCredentialRequestOptions
        });
        const credential = createAuthenicationCredentialForServer(result);
        await asyncAjax({
            url: '/api/login',
            type: 'POST',
            contentType: 'application/json',
            data: JSON.stringify(credential),
            dataType: 'text',
            processData: false
        })
        alert("Success")
    } catch(error) {
        alert(`Login failed: ${error.message}`)
    }
}

/**
 * Test authentication details
 */
async function test() {
    try {
        const response = await asyncAjax({
            url: '/api/test',
            type: 'GET',
            dataType: 'json'
        })
        return response.id
    } catch(error) {
        return "Failed to get authenication data";
    }
}

/**
 * Async/await version of $.ajax
 * @param {*} request Ajax request object
 * @returns Response from Ajax call
 */
function asyncAjax(request) {
    return new Promise((resolve, reject) => {
        $.ajax({
            url: request.url,
            type: request.type,
            contentType: request.contentType,
            data: request.data,
            dataType: request.dataType,
            processData: request.processData,
            success: function(data) {
                resolve(data)
            },
            error: function(error) {
                reject(error)
            }
        })
    });
}

/**
 * Convert server response from /api/beginregister to PublicKeyCredentialCreationOptions
 * @param {*} response Server response from /api/beginregister   
 * @returns PublicKeyCredentialCreationOptions
 */
function createPublicKeyCredentialCreationOptionsFromServerResponse(response) {
    return  {
        challenge: Uint8Array.from(atob(response.challenge), c => c.charCodeAt(0)),
        rp: response.relyingParty,
        user: {
            id: Uint8Array.from(response.user.id, c => c.charCodeAt(0)),
            name: response.user.name,
            displayName: response.user.displayName,
        },
        pubKeyCredParams: response.publicKeyCredentialParameters.map(item => { return {alg: item.algorithm, type: item.type};}),
        timeout: response.timeout,
    };
}

/**
 * Convert return value from navigator.credentials.create to input JSON for /api/finishregister
 * @param {*} registrationCredential Result of navigator.credentials.create
 * @returns Input for /api/finishregister
 */
function createRegistrationCredentialForServer(registrationCredential) {
    return {
        authenicatorAttachment: registrationCredential.authenicatorAttachment,
        id: registrationCredential.id,
        rawId: btoa(String.fromCharCode(...new Uint8Array(registrationCredential.rawId))),
        type: registrationCredential.type,
        response: {
            attestationObject: btoa(String.fromCharCode(...new Uint8Array(registrationCredential.response.attestationObject))),
            clientDataJSON: btoa(String.fromCharCode(...new Uint8Array(registrationCredential.response.clientDataJSON)))
        }
    }
}

/**
 * Convert return value from GET /api/login to PublicKeyCredentialRequestOptions
 * @param {*} response Server response from GET /api/login
 * @returns PublicKeyCredentialRequestOptions
 */
function createPublicKeyCredentialRequestOptionsFromServerResponse(response) {
    return {
        challenge: Uint8Array.from(atob(response.challenge), c => c.charCodeAt(0)),
        allowCredentials: response.allowCredentials,
        timeout: response.timeout,
    }
}

/**
 * Convert return value of navigator.credentials.get to input JSON for POST /api/login
 * @param {*} credential Result of navigator.credentials.get
 * @returns Input for POST /api/login
 */
function createAuthenicationCredentialForServer(credential) {
    return {
        id: credential.id,
        authenticatorAttachment: credential.authenticatorAttachment,
        type: credential.type,
        response: {
            authenticatorData: btoa(String.fromCharCode(...new Uint8Array(credential.response.authenticatorData))),
            clientDataJSON: btoa(String.fromCharCode(...new Uint8Array(credential.response.clientDataJSON))),
            signature: btoa(String.fromCharCode(...new Uint8Array(credential.response.signature))),
            userHandle: String.fromCharCode(...new Uint8Array(credential.response.userHandle))
        }
    }
}