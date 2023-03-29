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
async function register(username) {
    try {
        let data = {
            "name": username
        }
        // signup api call
        const response = await fetch('/api/signup', {
            method: 'POST',
            headers: {"content-type": "application/json"},
            body: JSON.stringify(data)
        });
        switch (response.status ) {
        case 200:
            break
        case 409:
            throw Error("Username already exist");
        default:
            throw Error(`Error: status code: ${response.status}`)
        }
        const responseJSON = await response.json();
        const publicKeyCredentialCreationOptions = createPublicKeyCredentialCreationOptionsFromServerResponse(responseJSON);
        const result = await navigator.credentials.create({publicKey: publicKeyCredentialCreationOptions});
        const registrationCredential = createRegistrationCredentialForServer(result);
        // finish registration api call
        const finishResponse = await fetch('/api/finishregister', {
            method: "POST",
            headers: {"content-type": "application/json"},
            body: JSON.stringify(registrationCredential)
        });
        if (finishResponse.status !== 200) {
            throw Error(`Error: status code: ${finishResponse.status}`)
        }
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
        // initiate login
        const response = await fetch('/api/login')
        if (response.status !== 200) {
            throw Error(`Error: status code: ${response.status}`)
        }
        const responseBody = await response.json()
        const publicKeyCredentialRequestOptions = createPublicKeyCredentialRequestOptionsFromServerResponse(responseBody)
        const result = await navigator.credentials.get({
            publicKey: publicKeyCredentialRequestOptions
        });
        const credential = createAuthenicationCredentialForServer(result);
        // finish login
        const finishResponse = await fetch('/api/login', {
            method: 'POST',
            headers: {"content-type": 'application/json'},
            body: JSON.stringify(credential)
        });
        if (finishResponse.status !== 200) {
            throw Error(`Error: status code: ${finishResponse.status}`)
        }
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
        const response = await fetch('/api/test')
        if (response.status !== 200) {
            throw Error(`Error: status code: ${response.status}`)
        }
        const responseJSON = await response.json();
        return JSON.stringify(responseJSON);
    } catch(error) {
        return "Failed to get authenication data";
    }
}

/**
 * Convert server response from /api/beginregister to PublicKeyCredentialCreationOptions
 * @param {*} response Server response from /api/beginregister   
 * @returns PublicKeyCredentialCreationOptions
 */
function createPublicKeyCredentialCreationOptionsFromServerResponse(response) {
    return  {
        challenge: Uint8Array.from(atob(response.challenge), c => c.charCodeAt(0)),
        rp: response.rp,
        user: {
            id: Uint8Array.from(response.user.id, c => c.charCodeAt(0)),
            name: response.user.name,
            displayName: response.user.displayName,
        },
        pubKeyCredParams: response.pubKeyCredParams,
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