//
//  TextView.swift
//  ios-image-server
//
//  Created by Adam Fowler on 26/04/2021.
//

import SwiftUI

struct TextView: UIViewRepresentable {

    @Binding var text: String
    @Binding var textStyle: UIFont.TextStyle

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        textView.font = UIFont.preferredFont(forTextStyle: textStyle)
        textView.autocapitalizationType = .none
        textView.isSelectable = false
        textView.isUserInteractionEnabled = false

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        uiView.font = UIFont.preferredFont(forTextStyle: textStyle)
    }
}
