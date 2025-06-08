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
import Mustache

/// A structure that generates an HTML response.
struct HTML: ResponseGenerator {
    /// The HTML content to be included in the response.
    let html: String

    /// Generates a response from the given request and context.
    ///
    /// - Parameters:
    ///   - request: The incoming request.
    ///   - context: The context for the request.
    /// - Returns: A `Response` object containing the HTML content.
    public func response(from request: Request, context: some RequestContext) -> Response {
        let buffer = ByteBuffer(string: self.html)
        return Response(status: .ok, headers: [.contentType: "text/html"], body: .init(byteBuffer: buffer))
    }
}

/// A controller for handling web requests and generating responses.
struct WebController {
    /// The Mustache library used for rendering templates.
    let library: MustacheLibrary

    /// The Mustache template for entering user details.
    let enterTemplate: MustacheTemplate

    /// The Mustache template for displaying entered details.
    let enteredTemplate: MustacheTemplate

    /// The virtual file system for storing and retriving files.
    let fileSystem: VirtualFileSystem

    /// Initializes a new instance of `WebController`.
    ///
    /// - Parameters:
    ///   - mustacheLibrary: The Mustache library for template rendering.
    ///   - fileSystem: A virtual file system (defaults to a new instance).
    init(
        mustacheLibrary: MustacheLibrary,
        fileSystem: VirtualFileSystem = VirtualFileSystem()
    ) {
        self.library = mustacheLibrary
        self.enterTemplate = mustacheLibrary.getTemplate(named: "enter-details")!
        self.enteredTemplate = mustacheLibrary.getTemplate(named: "details-entered")!
        self.fileSystem = fileSystem
    }

    /// Adds routes to the specified router.
    func addRoutes(to router: some RouterMethods<some RequestContext>) {
        router.get("/", use: self.input)
        router.post("/", use: self.post)
        router.get("files/:filename", use: self.files)
    }

    /// Renders the input form for user details.
    @Sendable func input(request: Request, context: some RequestContext) -> HTML {
        let html = self.enterTemplate.render((), library: self.library)
        return HTML(html: html)
    }

    /// Handles the submission of user details and saves the profile picture.
    @Sendable func post(request: Request, context: some RequestContext) async throws -> HTML {
        let user = try await request.decode(as: User.self, context: context)
        let filename = user.profilePicture.filename
        let urlSafeFilename = user.profilePicture.urlSafeFilename
        await fileSystem.save(filename: urlSafeFilename, contents: user.profilePicture)

        let context: [String: Any] = [
            "name": user.name,
            "age": user.age,
            "profilePictureURL": "/files/\(urlSafeFilename)",
            "profilePictureFilename": filename,
        ]
        let html = self.enteredTemplate.render(context, library: self.library)
        return HTML(html: html)
    }

    /// Retrieves a file from the virtual file system.
    @Sendable func files(_ request: Request, context: some RequestContext) async throws -> Response {
        let filename = try context.parameters.require("filename", as: String.self)
        guard let file = await fileSystem.load(filename: filename) else {
            throw HTTPError(.notFound, message: "A file with the specified name was not found")
        }
        return Response(
            status: .ok,
            headers: self.headers(for: file),
            body: ResponseBody(byteBuffer: file.data)
        )
    }

    /// Generates the HTTP headers for a given file.
    private func headers(for file: File) -> HTTPFields {
        return [
            .contentDisposition: "attachment; filename=\"\(file.filename)\"",
            .contentType: file.contentType,
        ]
    }
}
