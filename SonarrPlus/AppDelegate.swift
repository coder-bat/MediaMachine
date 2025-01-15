//
//  AppDelegate.swift
//  SonarrPlus
//
//  Created by Coder Bat on 12/1/2025.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        NotificationManager.shared.requestAuthorization()
        let viewModel = SonarrPlusViewModel.shared
        viewModel.checkForUpcomingEpisodes()
        return true
    }
}
