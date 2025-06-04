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

struct HTML: ResponseGenerator {
    let html: String

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let buffer = ByteBuffer(string: self.html)
        return .init(status: .ok, headers: [.contentType: "text/html"], body: .init(byteBuffer: buffer))
    }
}

struct WebController {
    let library: MustacheLibrary
    let enterTemplate: MustacheTemplate
    let enteredTemplate: MustacheTemplate
    let fileSystem: VirtualFileSystem

    init(
        mustacheLibrary: MustacheLibrary,
        fileSystem: VirtualFileSystem = VirtualFileSystem()
    ) {
        self.library = mustacheLibrary
        self.enterTemplate = mustacheLibrary.getTemplate(named: "enter-details")!
        self.enteredTemplate = mustacheLibrary.getTemplate(named: "details-entered")!
        self.fileSystem = fileSystem
    }

    func addRoutes(to router: some RouterMethods<some RequestContext>) {
        router.get("/", use: self.input)
        router.post("/", use: self.post)
        router.get("files/:filename", use: self.files)
    }

    @Sendable func input(request: Request, context: some RequestContext) -> HTML {
        let html = self.enterTemplate.render((), library: self.library)
        return HTML(html: html)
    }

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

    @Sendable func files(_ request: Request, context: some RequestContext) async throws -> Response {
        let filename = try context.parameters.require("filename", as: String.self)
        guard let file = await fileSystem.load(filename: filename) else {
            throw HTTPError(.notFound, message: "a file with the specified name was not found")
        }
        return Response(
            status: .ok,
            headers: self.headers(for: file),
            body: ResponseBody(byteBuffer: file.data)
        )
    }

    private func headers(for file: File) -> HTTPFields {
        return [
            .contentDisposition: "attachment;filename=\"\(file.filename)\"",
            .contentType: file.contentType,
        ]
    }
}
