//
//  ContractorHoursPayApp.swift
//  ContractorHoursPay
//
//  Created by Luis Martinez on 22/08/2026.
//

import SwiftUI

@main
struct ContractorHoursPayApp: App {
    @StateObject private var authManager = AuthManager()

    init() {
        AppConfig.logDebugConfiguration()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
        }
    }
}
