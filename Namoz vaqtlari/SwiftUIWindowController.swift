//
//  SwiftUIWindowController.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//
//  A generic window controller for displaying SwiftUI views in AppKit windows.
//  Used to show Settings and Monthly Prayer views as separate windows.

import AppKit
import SwiftUI

/// A generic window controller that wraps SwiftUI views in AppKit windows.
/// Allows showing SwiftUI content in traditional macOS windows with title bars and close buttons.
/// Type parameter `Content` must conform to SwiftUI's `View` protocol.
class SwiftUIWindowController<Content: View>: NSWindowController {
    
    /// Creates a new window controller with the specified SwiftUI content.
    /// - Parameters:
    ///   - title: The window title (e.g., "Sozlamalar" or "Oylik Namoz Vaqtlari")
    ///   - content: The SwiftUI view to display inside the window
    ///   - width: The window width in points (default: 400)
    ///   - height: The window height in points (default: 300)
    init(title: String, content: Content, width: CGFloat = 400, height: CGFloat = 300) {
        // Wrap the SwiftUI view in a hosting controller
        let hosting = NSHostingController(rootView: content)
        
        // Create the window with specified dimensions
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable],  // Window has title bar and close button
            backing: .buffered,               // Use buffered backing store for better performance
            defer: false                      // Create window immediately
        )
        
        // Set window properties
        window.title = title
        window.contentViewController = hosting

        // Initialize the window controller
        super.init(window: window)
        
        // Enable window cascading (each new window appears offset from the previous one)
        self.shouldCascadeWindows = true
        
        // Center the window on screen
        self.window?.center()
        
        // Show the window
        self.showWindow(nil)
    }

    /// Required initializer for NSCoding (not used, so it crashes if called)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
