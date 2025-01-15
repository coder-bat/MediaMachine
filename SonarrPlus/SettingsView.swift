//
//  SettingsView.swift
//  SonarrPlus
//
//  Created by Coder Bat on 14/1/2025.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var isFeedbackPresented = false

    var body: some View {
        NavigationView {
            Form {
                // App Settings Section
                Section(header: Text("App Settings")) {
                    Section(header: Text("General")) {
                        Text("App Version: 1.0.0") // Placeholder for future settings
                    }

                    Section(header: Text("Notifications")) {
                        NavigationLink(destination: NotificationSettingsView()) {
                            Text("Enable new episode notifications")
                        }
                    }
                }

                // Appearance Section
                Section(header: Text("Appearance")) {
                    Toggle(isOn: $isDarkMode) {
                        Text("Dark Mode")
                    }
                }

                // Support Section
                Section(header: Text("Support")) {
                    Button(action: {
                        isFeedbackPresented = true
                    }) {
                        HStack {
                            SwiftUI.Image(systemName: "envelope")
                            Text("Send Feedback")
                        }
                    }
                    .sheet(isPresented: $isFeedbackPresented) {
                        FeedbackView(isPresented: $isFeedbackPresented)
                    }
                }

                // Footer
                Section {
                    VStack {
                        Text("Made with ❤️ by coder_bat")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Button(action: {
                            if let url = URL(string: "https://lovepeaceand.dev") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("lovepeaceand.dev")
                                .font(.footnote)
                                .underline()
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
