import SwiftUI

struct EpisodeDetailView: View {
    let episode: Episode
    @State private var isMonitored: Bool
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isSearching = false
    @StateObject private var viewModel = MediaMachineViewModel.shared
    @Environment(\.dismiss) private var dismiss

    init(episode: Episode) {
        self.episode = episode
        _isMonitored = State(initialValue: episode.monitored)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with Episode Info
            HStack(spacing: 20) {
                // Meta Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("S\(episode.seasonNumber)E\(episode.episodeNumber): \(episode.title)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    if let airDate = episode.airDate {
                        HStack {
                            SwiftUI.Image(systemName: "calendar")
                            Text("Air Date: \(formatDate(airDate))")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }

                    if episode.hasFile {
                        Text("Available in disk")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    } else {
                        Text("Not in disk")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)

            // Overview
            if let overview = episode.overview {
                InfoSection(title: "Overview") {
                    Text(overview)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
            }

            // Monitor Toggle
            InfoSection(title: "Monitor Episode") {
                Toggle(isOn: $isMonitored) {
                    Text("Monitored")
                        .font(.headline)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .onChange(of: isMonitored) { newValue in
                    updateEpisodeMonitoring()
                }
            }

            // Action Buttons
//            VStack(spacing: 12) {
//                // Search Button (only show if indexers are available)
                if viewModel.hasIndexers {
                    Button(action: {
                        searchEpisode()
                    }) {
                        HStack {
                            SwiftUI.Image(systemName: "magnifyingglass")
                            Text("Search Episode")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                    .disabled(isSearching)
                    .opacity(isSearching ? 0.6 : 1.0)
                }
//
//                // Delete Button (only show if episode has file)
                if episode.hasFile {
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            SwiftUI.Image(systemName: "trash")
                            Text("Delete Episode File")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                    .disabled(isDeleting)
                    .opacity(isDeleting ? 0.6 : 1.0)
                }
//            }
//            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Episode File", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteEpisodeFile()
            }
        } message: {
            Text("Are you sure you want to delete this episode file? This will remove the file from disk.")
        }
        // TODO fixme
//        .onAppear {
//            viewModel.checkIndexers()
//        }
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

    private func updateEpisodeMonitoring() {
        viewModel.updateEpisodeMonitoring(episodeId: episode.id, monitored: isMonitored) { success in
            if !success {
                // Revert the toggle if update failed
                isMonitored = !isMonitored
            }
        }
    }

    private func searchEpisode() {
        isSearching = true
        viewModel.searchEpisode(episodeId: episode.id) { success in
            isSearching = false
            if success {
                // Optionally show success message
            }
        }
    }

    private func deleteEpisodeFile() {
        isDeleting = true
        viewModel.deleteEpisodeFile(episodeId: episode.id) { success in
            isDeleting = false
            if success {
                dismiss()
            }
        }
    }
}
