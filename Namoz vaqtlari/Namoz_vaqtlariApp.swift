//
//  Namoz_vaqtlariApp.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//
//  Main entry point for the prayer times menu bar application.
//  This is a minimal app structure that delegates all functionality to AppDelegate.

import SwiftUI

/// Main application structure for the prayer times app.
/// Uses AppDelegate for all functionality since this is a menu bar app without a main window.
@main
struct Namoz_vaqtlariApp: App {
    
    /// Connects the AppDelegate to SwiftUI's app lifecycle.
    /// All app logic and UI is handled by AppDelegate, not by this SwiftUI app structure.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// The app's scene configuration.
    /// We use an empty Settings scene since this is a menu bar-only app with no main window.
    /// The actual UI (menu bar item, settings window, monthly view) is managed by AppDelegate.
    var body: some Scene {
        Settings {
            EmptyView() // No main window - everything is in the menu bar
        }
    }
}
