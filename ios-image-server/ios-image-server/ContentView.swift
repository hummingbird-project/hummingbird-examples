//
//  ContentView.swift
//  ios-image-server
//
//  Created by Adam Fowler on 26/04/2021.
//

import Hummingbird
import Logging
import SwiftUI

struct ContentView: View {
    @State private var logText = ""
    @State private var logTextStyle = UIFont.TextStyle.caption1
    @State private var showingAlert = false
    @State private var alertText = Text("")

    var body: some View {
        TextView(text: $logText, textStyle: $logTextStyle)
            .padding()
            .onAppear {
                LoggingSystem.bootstrap { label in StringLogHandler(label: label, string: $logText) }
                let app = HBApplication.run()
                if let loginToken = app.loginToken {
                    self.alertText = Text("Please enter \"\(loginToken)\" to view images")
                    self.showingAlert = true
                }
            }
            .alert(isPresented: $showingAlert, content: {
                Alert(title: Text("iOS Image Server"), message: alertText)
            })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
