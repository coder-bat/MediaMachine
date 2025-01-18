//
//  MediaMachineApp.swift
//  MediaMachine
//
//  Created by Coder Bat on 12/1/2025.
//

import SwiftUI

@main
struct MediaMachineApp: App {
    @StateObject private var viewModel = MediaMachineViewModel.shared
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("hasSeenWalkthrough") private var hasSeenWalkthrough = false

    var body: some Scene {
        WindowGroup {
            if hasSeenWalkthrough {
                if viewModel.isAuthenticated {
                    MainView()
                        .environmentObject(viewModel)
                        .onAppear {
                            NotificationManager.shared.requestAuthorization()
                            viewModel.checkForUpcomingEpisodes()
                        }
                        .preferredColorScheme(isDarkMode ? .dark : .light)
                } else {
                    ContentView()
                        .environmentObject(viewModel)
                        .onAppear {
                            NotificationManager.shared.requestAuthorization()
                        }
                        .preferredColorScheme(isDarkMode ? .dark : .light)
                }
            } else {
                WalkthroughView()
                    .onDisappear {
                        hasSeenWalkthrough = true
                    }
            }
        }
    }
}
