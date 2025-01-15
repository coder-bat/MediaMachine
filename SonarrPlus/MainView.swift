import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: SonarrPlusViewModel

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

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                }
                .accentColor(.blue) // Tab bar tint color
            }
            .navigationTitle("SonarrPlus")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
