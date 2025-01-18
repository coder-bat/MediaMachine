import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: MediaMachineViewModel

    var body: some View {
        NavigationView {
            VStack {
                TabView {
                    DiscoverView()
                        .tabItem {
                            Label("Discover", systemImage: "lightbulb")
                        }

                    StatsDashboardView()
                        .tabItem {
                            Label("Stats", systemImage: "chart.bar")
                        }

                    LibraryView()
                        .tabItem {
                            Label("Library", systemImage: "film")
                        }

                    DownloadManagerView()
                        .tabItem {
                            Label("Downloads", systemImage: "arrow.down.circle")
                        }
                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                }
                .accentColor(.blue) // Tab bar tint color
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
