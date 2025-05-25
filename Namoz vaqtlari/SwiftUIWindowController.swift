//
//  SwiftUIWindowController.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//


import AppKit
import SwiftUI

class SwiftUIWindowController<Content: View>: NSWindowController {
    init(title: String, content: Content, width: CGFloat = 400, height: CGFloat = 300) {
        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentViewController = hosting

        super.init(window: window)
        self.shouldCascadeWindows = true
        self.window?.center()
        self.showWindow(nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}