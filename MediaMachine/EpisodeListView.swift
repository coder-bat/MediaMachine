import SwiftUI

struct EpisodeListView: View {
    let show: Show
    let seasonNumber: Int
    @State private var episodes: [Episode] = []
    @EnvironmentObject var viewModel: MediaMachineViewModel
    @State private var isLoading = false
    @State private var showError = false

    var body: some View {
        List(episodes) { episode in
            NavigationLink(destination: EpisodeDetailView(episode: episode)) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("S\(seasonNumber)E\(episode.episodeNumber): \(episode.title)")
                        .font(.headline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    if let airDate = episode.airDate {
                        Text("Air Date: \(formatDate(airDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        if episode.hasFile {
                            Text("Downloaded")
                                .foregroundColor(.green)
                        } else {
                            Text("Not in server")
                                .foregroundColor(.red)
                        }

                        if episode.monitored {
                            Text("Monitored")
                                .foregroundColor(.blue)
                        } else {
                            Text("Not Monitored")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            loadEpisodes()
        }
        .navigationTitle("Season \(seasonNumber)")
    }

    // Helper functions
    private func formatDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }

    private func loadEpisodes() {
        isLoading = true
        viewModel.fetchEpisodes(for: show) { result in
            isLoading = false
            switch result {
            case .success(let allEpisodes):
                self.episodes = allEpisodes.filter { $0.seasonNumber == seasonNumber }
                    .sorted { $0.episodeNumber < $1.episodeNumber }
            case .failure(let error):
                print("Failed to load episodes: \(error)")
                self.showError = true
            }
        }
    }
}
