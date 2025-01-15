//
//  SonarrAppApp.swift
//  SonarrApp
//
//  Created by Coder Bat on 12/1/2025.
//

import SwiftUI

@main
struct SonarrPlusApp: App {
    @StateObject private var viewModel = SonarrPlusViewModel.shared
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some Scene {
        WindowGroup {
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
        }
    }
}
