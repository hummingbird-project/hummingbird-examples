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
import Logging
import SwiftUI

struct ContentView: View {
    @State private var logText = ""
    @State private var logTextStyle = UIFont.TextStyle.caption1
    @State private var showingAlert = false
    @State private var alertText = Text("")

    var body: some View {
        TextView(text: self.$logText, textStyle: self.$logTextStyle)
            .padding()
            .onAppear {
                // setup logging
                LoggingSystem.bootstrap { label in StringLogHandler(label: label, string: self.$logText) }
                // create server app
                let app = HBApplication.run()
                // if app has a login token then display dialog
                if let loginToken = app.loginToken {
                    self.alertText = Text("Your login token is \"\(loginToken)\"")
                    self.showingAlert = true
                }
            }
            .alert(isPresented: self.$showingAlert, content: {
                Alert(title: Text("iOS Image Server"), message: self.alertText)
            })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
