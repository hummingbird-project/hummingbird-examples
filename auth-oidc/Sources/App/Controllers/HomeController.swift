//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2025 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
import HummingbirdAuth
import HummingbirdOIDC

struct HomeController {
    typealias Context = AppRequestContext

    let oidc: OIDC

    func addRoutes(to group: RouterGroup<Context>) {
        group
            .add(middleware: OIDCSessionAuthenticator(oidc: oidc))
            .get(use: self.home)
    }

    @Sendable func home(_ request: Request, _ context: Context) -> Response {
        let identity = try? context.requireIdentity()
        let html = identity.map(loggedInPage) ?? loggedOutPage()
        return Response(
            status: .ok,
            headers: [.contentType: "text/html; charset=utf-8"],
            body: .init(byteBuffer: .init(string: html))
        )
    }

    private func loggedOutPage() -> String {
        page(title: "Welcome") {
            """
            <div class="card">
              <h2>You are not signed in</h2>
              <p>Sign in with your account to continue.</p>
              <a href="/auth/login" class="btn btn-primary">Sign in</a>
            </div>
            """
        }
    }

    private func loggedInPage(_ identity: OIDCIdentity) -> String {
        let displayName = identity.claims.name ?? identity.claims.email ?? identity.subject
        let rows = [
            ("Name", identity.claims.name),
            ("Email", identity.claims.email),
            ("Subject", Optional(identity.subject)),
            ("Issuer", Optional(identity.issuer)),
        ]
        .compactMap { label, value -> String? in
            guard let value else { return nil }
            return "<tr><th>\(label)</th><td>\(escapeHTML(value))</td></tr>"
        }
        .joined(separator: "\n")

        return page(title: "Welcome, \(escapeHTML(displayName))") {
            """
            <div class="card">
              <h2>Signed in as \(escapeHTML(displayName))</h2>
              <table>\(rows)</table>
              <form method="post" action="/auth/logout" style="margin-top:1.5rem">
                <button type="submit" class="btn btn-danger">Sign out</button>
              </form>
            </div>
            """
        }
    }

    private func page(title: String, body: () -> String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escapeHTML(title))</title>
          <style>
            *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
            body {
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
              background: #f5f5f7;
              color: #1d1d1f;
              display: flex;
              align-items: center;
              justify-content: center;
              min-height: 100vh;
              padding: 2rem;
            }
            .card {
              background: #fff;
              border-radius: 18px;
              box-shadow: 0 4px 24px rgba(0,0,0,.08);
              padding: 2.5rem 3rem;
              max-width: 480px;
              width: 100%;
            }
            h2 { font-size: 1.4rem; margin-bottom: .75rem; }
            p  { color: #6e6e73; margin-bottom: 1.5rem; }
            table { width: 100%; border-collapse: collapse; margin-top: .5rem; }
            th, td { text-align: left; padding: .45rem .5rem; font-size: .9rem; }
            th { color: #6e6e73; font-weight: 500; width: 30%; }
            tr + tr th, tr + tr td { border-top: 1px solid #f0f0f0; }
            .btn {
              display: inline-block;
              padding: .6rem 1.4rem;
              border-radius: 980px;
              font-size: .95rem;
              font-weight: 500;
              text-decoration: none;
              cursor: pointer;
              border: none;
            }
            .btn-primary { background: #0071e3; color: #fff; }
            .btn-primary:hover { background: #0077ed; }
            .btn-danger  { background: #ff3b30; color: #fff; }
            .btn-danger:hover  { background: #ff453a; }
          </style>
        </head>
        <body>
          \(body())
        </body>
        </html>
        """
    }

    private func escapeHTML(_ s: String) -> String {
        s.replacing("&", with: "&amp;")
         .replacing("<", with: "&lt;")
         .replacing(">", with: "&gt;")
         .replacing("\"", with: "&quot;")
    }
}
