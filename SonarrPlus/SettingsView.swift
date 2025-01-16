import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage(AppStorageKeys.serverURL) private var serverURL = ""
    @AppStorage(AppStorageKeys.apiKey) private var apiKey = ""
    @State private var isFeedbackPresented = false
    @State private var showDisconnectAlert = false
    @EnvironmentObject var viewModel: SonarrPlusViewModel

    var body: some View {
        NavigationStack {
            // Changed from NavigationView to NavigationStack
            Form {
                // Connection Status Section
                if !serverURL.isEmpty {
                    Section {
                        Text("Connected to: \(serverURL)")
                    } header: {
                        Text("Connection")
                    }
                    Button(action: {
                        showDisconnectAlert = true
                    }) {
                        HStack {
                            SwiftUI.Image(systemName: "disconnect.circle.fill")
                                .foregroundColor(.red)
                            Text("Disconnect from Sonarr")
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    Section {
                        Text("Not connected to any server")
                    } header: {
                        Text("Connection")
                    }
                }
                
                // App Settings Section
                Section {
                    Text("App Version: 1.0.0")
                } header: {
                    Text("General")
                }

                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Text("Enable new episode notifications")
                    }
                } header: {
                    Text("Notifications")
                }

                // Appearance Section
                Section {
                    Toggle(isOn: $isDarkMode) {
                        Text("Dark Mode")
                    }
                } header: {
                    Text("Appearance")
                }

                // Support Section
                Section {
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
                } header: {
                    Text("Support")
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
            .alert("Disconnect from Sonarr?", isPresented: $showDisconnectAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) {
                    // Clear stored credentials
                    serverURL = ""
                    apiKey = ""
                    viewModel.isAuthenticated = false
                }
            } message: {
                Text("This will remove your saved connection settings, close the app. You'll need to reconnect next time when you use the app.")
            }
        }
    }
}
