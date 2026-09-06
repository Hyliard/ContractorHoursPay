//
//  AuthDemoApp.swift
//  AuthDemo
//
//  Created by Luis Martinez on 22/08/2026.
//

import SwiftUI

@main
struct AuthDemoApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
        }
    }
}
