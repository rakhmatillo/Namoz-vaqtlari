//
//  Namoz_vaqtlariApp.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//

import SwiftUI

@main
struct Namoz_vaqtlariApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // We don't need a main window
        }
    }
}
