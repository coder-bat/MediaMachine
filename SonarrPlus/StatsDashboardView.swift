import SwiftUI

struct StatsDashboardView: View {
    @StateObject private var viewModel = SonarrPlusViewModel.shared

    var body: some View {
        NavigationView {
            VStack {
                if let stats = viewModel.stats {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Total Shows:")
                            Spacer()
                            Text("\(stats.totalShows ?? 0)")
                                .bold()
                        }
                        HStack {
                            Text("Disk Space Used:")
                            Spacer()
                            Text("\(String(format: "%.2f", stats.diskSpaceUsed ?? 0.0)) GB")
                                .bold()
                        }
                        HStack {
                            Text("Disk Space Free:")
                            Spacer()
                            Text("\(String(format: "%.2f", stats.diskSpaceFree ?? 0.0)) GB")
                                .bold()
                        }
                    }
                    .padding()
                } else {
                    ProgressView("Loading stats...")
                }
            }
            .navigationTitle("Server Stats")
            .onAppear {
                Task {
                    await viewModel.fetchStats()
                }
            }
        }
    }
}
