import SwiftUI

struct EpisodeRowView: View {
    let episode: Episode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("E\(episode.episodeNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)

                Text(episode.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            if let airDate = episode.airDate {
                Text(formatDate(airDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                if episode.hasFile {
                    SwiftUI.Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }

                if episode.monitored {
                    SwiftUI.Image(systemName: "eye.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
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
