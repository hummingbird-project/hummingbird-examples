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
            "username": username
        }
        // signup api call
        const response = await fetch('/api/user/signup', {
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
        const finishResponse = await fetch('/api/user/register/finish', {
            method: "POST",
            headers: {"content-type": "application/json"},
            body: JSON.stringify(registrationCredential)
        });
        if (finishResponse.status !== 200) {
            throw Error(`Error: status code: ${finishResponse.status}`)
        }
        location = "/login.html";
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
        const response = await fetch('/api/user/login')
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
        const finishResponse = await fetch('/api/user/login', {
            method: 'POST',
            headers: {"content-type": 'application/json'},
            body: JSON.stringify(credential)
        });
        if (finishResponse.status !== 200) {
            throw Error(`Error: status code: ${finishResponse.status}`)
        }
        location = "/";
    } catch(error) {
        alert(`Login failed: ${error.message}`)
    }
}

/**
 * Login user
 */
async function logout() {
    try {
        // initiate login
        const response = await fetch('/api/user/logout')
        if (response.status !== 200) {
            throw Error(`Error: status code: ${response.status}`)
        }
        location.reload();
    } catch(error) {
        alert(`Logout failed: ${error.message}`)
    }
}

/**
 * Test authentication details
 */
async function test() {
    try {
        const response = await fetch('/api/user/test')
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
 * Convert server response from /api/user/beginregister to PublicKeyCredentialCreationOptions
 * @param {*} response Server response from /api/user/beginregister   
 * @returns PublicKeyCredentialCreationOptions
 */
function createPublicKeyCredentialCreationOptionsFromServerResponse(response) {
    const challenge = bufferDecode(response.challenge);
    const userId = bufferDecode(response.user.id);
    return  {
        challenge: challenge,
        rp: response.rp,
        user: {
            id: userId,
            name: response.user.name,
            displayName: response.user.displayName,
        },
        pubKeyCredParams: response.pubKeyCredParams,
        timeout: response.timeout,
    };
}

/**
 * Convert return value from navigator.credentials.create to input JSON for /api/user/finishregister
 * @param {*} registrationCredential Result of navigator.credentials.create
 * @returns Input for /api/user/finishregister
 */
function createRegistrationCredentialForServer(registrationCredential) {
    return {
        authenicatorAttachment: registrationCredential.authenicatorAttachment,
        id: registrationCredential.id,
        rawId: bufferEncode(registrationCredential.rawId),
        type: registrationCredential.type,
        response: {
            attestationObject: bufferEncode(registrationCredential.response.attestationObject),
            clientDataJSON: bufferEncode(registrationCredential.response.clientDataJSON)
        }
    }
}

/**
 * Convert return value from GET /api/user/login to PublicKeyCredentialRequestOptions
 * @param {*} response Server response from GET /api/user/login
 * @returns PublicKeyCredentialRequestOptions
 */
function createPublicKeyCredentialRequestOptionsFromServerResponse(response) {
    return {
        challenge: bufferDecode(response.challenge),
        allowCredentials: response.allowCredentials,
        timeout: response.timeout,
    }
}

/**
 * Convert return value of navigator.credentials.get to input JSON for POST /api/user/login
 * @param {*} credential Result of navigator.credentials.get
 * @returns Input for POST /api/user/login
 */
function createAuthenicationCredentialForServer(credential) {
    return {
        id: credential.id,
        rawId: bufferEncode(credential.rawId),
        authenticatorAttachment: credential.authenticatorAttachment,
        type: credential.type,
        response: {
            authenticatorData: bufferEncode(credential.response.authenticatorData),
            clientDataJSON: bufferEncode(credential.response.clientDataJSON),
            signature: bufferEncode(credential.response.signature),
            userHandle: bufferEncode(credential.response.userHandle)//String.fromCharCode(...new Uint8Array(credential.response.userHandle))
        }
    }
}

function bufferEncode(value) {
    return btoa(String.fromCharCode(...new Uint8Array(value)))
        .replace(/\+/g, "-")
        .replace(/\//g, "_")
        .replace(/=/g, "");
}

function bufferDecode(value) {
    return Uint8Array.from(atob(value.replace(/_/g, '/').replace(/-/g, '+')), c => c.charCodeAt(0));
}