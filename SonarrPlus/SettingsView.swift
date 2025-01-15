//
//  SettingsView.swift
//  SonarrPlus
//
//  Created by Coder Bat on 14/1/2025.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("General")) {
                        Text("App Version: 1.0.0") // Placeholder for future settings
                    }

                    Section(header: Text("Notifications")) {
                        NavigationLink(destination: NotificationSettingsView()) {
                            Text("Enable new episode notifications")
                        }
                    }
                }
                .listStyle(GroupedListStyle())
                
                Form {
                    Section(header: Text("Appearance")) {
                        Toggle(isOn: $isDarkMode) {
                            Text("Dark Mode")
                        }
                    }
                }

                
                Spacer() // Push the footer to the bottom
                
                // Footer Message
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
                .padding(.bottom, 10)
            }
            .navigationTitle("Settings")
        }
    }
}
