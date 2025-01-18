import SwiftUI

struct EpisodeListView: View {
    let show: Show
    let seasonNumber: Int
    @State private var episodes: [Episode] = []
    @EnvironmentObject var viewModel: MediaMachineViewModel

    var body: some View {
        List(episodes) { episode in
            VStack(alignment: .leading, spacing: 5) {
                Text("S\(seasonNumber)E\(episode.episodeNumber): \(episode.title)")
                    .font(.headline)
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
                        Text("Not Downloaded")
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
        }
        .onAppear {
            // Call the updated fetchEpisodes method
            viewModel.fetchEpisodes(forSeason: seasonNumber, show: show) { episodes in
                self.episodes = episodes
            }
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
}
