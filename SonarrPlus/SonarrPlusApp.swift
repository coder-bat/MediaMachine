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

    var body: some Scene {
        WindowGroup {
            if viewModel.isAuthenticated {
                MainView()
                    .environmentObject(viewModel)
                    .onAppear {
                        NotificationManager.shared.requestAuthorization()
                        viewModel.checkForUpcomingEpisodes()
                    }
            } else {
                ContentView()
                    .environmentObject(viewModel)
                    .onAppear {
                        NotificationManager.shared.requestAuthorization()
                    }
            }
        }
    }
}
