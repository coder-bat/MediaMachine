import SwiftUI

struct ShowDetailView: View {
    let show: Show // Existing functionality

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Show Poster
                if let posterPath = show.posterPath {
                    AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(8)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 300)
                            .cornerRadius(8)
                    }
                }

                // Show Title
                Text(show.title ?? "")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Show Status
                HStack {
                    Text("Status: \(show.status?.capitalized ?? "Undefined")")
                        .font(.headline)
                        .foregroundColor(show.ended ?? false ? .red : .green)
                    Spacer()
                    if show.monitored ?? false {
                        Text("Monitored")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    } else {
                        Text("Not Monitored")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }

                // Network and Runtime
                if let network = show.network, let runtime = show.runtime {
                    Text("\(network) • \(runtime) min per episode")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Overview
                if let overview = show.overview ?? show.overview {
                    Text("Overview")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(overview)
                        .font(.body)
                        .foregroundColor(.gray)
                }

                // Air Dates
                if let firstAired = show.firstAired, let nextAiring = show.nextAiring {
                    VStack(alignment: .leading) {
                        Text("First Aired: \(formatDate(firstAired))")
                        Text("Next Airing: \(formatDate(nextAiring))")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                // Seasons
                if let seasons = show.seasons {
                    Text("Seasons")
                        .font(.title2)
                        .fontWeight(.semibold)

                    ForEach(seasons) { season in
                        NavigationLink(destination: EpisodeListView(show: show, seasonNumber: season.seasonNumber)) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Season \(season.seasonNumber)")
                                    .font(.headline)
                                if let stats = season.statistics {
                                    Text("Episodes: \(stats.episodeFileCount)/\(stats.totalEpisodeCount)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("Percent Complete: \(String(format: "%.0f%%", stats.percentOfEpisodes ?? 0))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                    }
                }

                // Add to Sonarr for Discover Shows
                Button("Add to Sonarr") {
                    addShowToSonarr(show)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("Show Details")
    }

    // Helper function to format ISO 8601 dates
    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }

    @State private var isAddingToSonarr: Bool = false
    @State private var isAddedToSonarr: Bool = false

    // Add Discover Show to Sonarr
    private func addShowToSonarr(_ show: Show) {
        // Fetch quality profiles and ask user to select quality and download option
        MediaMachineViewModel.shared.fetchQualityProfiles { profiles in
            guard let profiles = profiles else { return }

            let qualityPicker = QualityPicker(profiles: profiles) { selectedProfile, startDownload in
                isAddingToSonarr = true // Disable the button while adding

                MediaMachineViewModel.shared.addShow(show: show, qualityProfileId: selectedProfile.id, startDownload: startDownload) {
                    DispatchQueue.main.async {
                        isAddingToSonarr = false
                        isAddedToSonarr = true // Update state to show success
                    }
                }
            }

            DispatchQueue.main.async {
                DispatchQueue.main.async {
                    let hostingController = UIHostingController(rootView: qualityPicker)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(hostingController, animated: true)
                    }
                }
            }
        }
    }
}
