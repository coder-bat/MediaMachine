import SwiftUI

struct ShowDetailView: View {
    let show: Show
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                // Header with Poster and Meta Info
                HStack(spacing: 20) {
                    // Poster
                    let posterURL = show.posterPath.map { "https://image.tmdb.org/t/p/w500\($0)" } ?? show.posterUrl

                    if let posterURL = posterURL, let url = URL(string: posterURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(radius: 8)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 160, height: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Meta Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(show.title ?? show.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        if let rating = show.voteAverage {
                            HStack {
                                SwiftUI.Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .fontWeight(.semibold)
                            }
                        }

                        StatusBadge(status: show.status ?? "Unknown", ended: show.ended ?? false)

                        if show.monitored ?? false {
                            Text("Monitored")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }

                        if let network = show.network {
                            HStack {
                                SwiftUI.Image(systemName: "tv")
                                Text(network)
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }

                        if let runtime = show.runtime {
                            HStack {
                                SwiftUI.Image(systemName: "clock")
                                Text("\(runtime) min")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)

                // Air Dates
                if let firstAired = show.firstAired {
                    InfoSection(title: "Air Dates") {
                        VStack(alignment: .leading, spacing: 8) {
                            DateRow(title: "First Aired", date: firstAired)
                            if let nextAiring = show.nextAiring {
                                DateRow(title: "Next Episode", date: nextAiring)
                            }
                        }
                    }
                }

                // Overview
                if let overview = show.overview {
                    InfoSection(title: "Overview") {
                        Text(overview)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                }

                // Seasons
                if let seasons = show.seasons {
                    InfoSection(title: "Seasons") {
                        VStack(spacing: 16) {
                            ForEach(seasons) { season in
                                NavigationLink(destination: EpisodeListView(show: show, seasonNumber: season.seasonNumber)) {
                                    SeasonCard(season: season, show: show)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Helper Views
struct StatusBadge: View {
    let status: String
    let ended: Bool

    var body: some View {
        Text(status)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ended ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
            .foregroundColor(ended ? .red : .green)
            .clipShape(Capsule())
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            content
        }
        .padding(.horizontal)
    }
}

struct DateRow: View {
    let title: String
    let date: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(formatDate(date))
                .fontWeight(.medium)
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct SeasonCard: View {
    let season: Season
    let show: Show
    @State private var isMonitored: Bool
    @State private var isUpdating = false
    @State private var lastUpdate = Date()
    @EnvironmentObject var viewModel: MediaMachineViewModel

    init(season: Season, show: Show) {
        self.season = season
        self.show = show
        _isMonitored = State(initialValue: season.monitored)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Season \(season.seasonNumber)")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isMonitored },
                    set: { newValue in
                        let now = Date()
                        guard now.timeIntervalSince(lastUpdate) > 0.5 else { return }
                        lastUpdate = now

                        guard !isUpdating else { return }
                        isUpdating = true
                        isMonitored = newValue

                        viewModel.updateSeasonMonitoring(
                            showId: show.id,
                            seasonNumber: season.seasonNumber,
                            monitored: newValue
                        ) { success in
                            if !success {
                                isMonitored = !newValue
                            }
                            isUpdating = false
                        }
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .disabled(isUpdating)
            }

            if let stats = season.statistics {
                // Progress
                HStack {
                    ProgressView(
                        value: Double(stats.episodeFileCount),
                        total: Double(stats.totalEpisodeCount)
                    )
                    .tint(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    Text("\(stats.episodeFileCount)/\(stats.totalEpisodeCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Episode Info
                HStack {
                    SwiftUI.Image(systemName: "film")
                    Text("\(stats.totalEpisodeCount) Episodes")
                    Spacer()
                    Text(formatSize(stats.sizeOnDisk))
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isUpdating ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isUpdating)
    }

    private func formatSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
