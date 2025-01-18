//
//  ShowListView.swift
//  MediaMachine
//
//  Created by Coder Bat on 18/1/2025.
//
import SwiftUI

struct ShowListView: View {
//    let show: Show // Existing functionality
    let currentShows: [Show] // Track added state by show ID
//    let discoverShow: DiscoverShow? // New functionality for DiscoverView integration

    @State private var addingToSonarr: [Int: Bool] = [:] // Track state by show ID
    @State private var addedToSonarr: [Int: Bool] = [:] // Track added state by show ID
    @EnvironmentObject var viewModel: MediaMachineViewModel

    var body: some View {
        // TODO update column based on columns passed in initialisation
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ]

        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(currentShows, id: \.id) { show in
                    NavigationLink(destination: ShowDetailView(show: show)) {
                        HStack {
                            // Show Poster
                            let posterURL = show.posterPath.map { "https://image.tmdb.org/t/p/w154\($0)" } ?? show.posterUrl

                            if let posterURL = posterURL, let url = URL(string: posterURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .frame(height: 120)
                                        .frame(width: 67)
                                        .cornerRadius(4)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 120)
                                        .frame(width: 67)
                                        .cornerRadius(4)
                                }
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 120)
                                    .frame(width: 67)
                                    .cornerRadius(4)
                                    .overlay(
                                        Text("No Image")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                // Show Title
                                Text(show.name)
                                    .font(.caption2)
                                    .bold()
                                    .padding(.vertical, 2)
                                    .multilineTextAlignment(.leading)

                                // Status
                                if let status = show.status?.capitalized {
                                    Text(status)
                                        .font(.caption2)
                                }

                                // Release Date
                                if let releaseDate = show.firstAirDate {
                                    Text("Released: \(releaseDate)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }

                                // Rating
                                if let rating = show.voteAverage {
                                    Text("Rating: \(rating, specifier: "%.1f")/10")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                // Monitored Status
                                
                                // Button (Only shown if monitored is nil)
                                if show.monitored == nil {
                                    Button(action: buttonAction(for: show)) {
                                        Text(buttonTitle(for: show))
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .padding(.top, 5)
                                    .disabled(addingToSonarr[show.id] == true)
                                } else {
                                    Text(show.monitored == true ? "Monitored" : "Not Monitored")
                                        .foregroundColor(show.monitored == true ? .green : .red)
                                        .font(.caption2)
                                }
                            }
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(4)
                    }
                }
            }
            .padding()
        }
    }
    private func buttonTitle(for show: Show) -> String {
        if addedToSonarr[show.id] == true {
            return "👀"
        } else if addingToSonarr[show.id] == true {
            return "..."
        } else {
            return "⊕ Add"
        }
    }

    private func buttonAction(for show: Show) -> () -> Void {
        return {
            if addedToSonarr[show.id] == true {
                openShowInSonarr(tvdbId: show.id)
            } else {
                addShowToSonarr(show)
            }
        }
    }
    func openShowInSonarr(tvdbId: Int) {
//        ShowDetailView(show: nil, discoverShow: show)
        guard let serverURL = viewModel.publicServerURL else { return }
        let showURL = "\(serverURL)/series/\(tvdbId)"
        if let url = URL(string: showURL) {
            UIApplication.shared.open(url)
        }
    }
    private func addShowToSonarr(_ show: Show) {
        viewModel.fetchRootFolders { rootFolders in
            guard let rootFolders = rootFolders, let rootFolderPath = rootFolders.first else {
                print("No valid root folders available.")
                return
            }

            viewModel.fetchTvdbId(for: show.name) { tvdbId in
                guard let tvdbId = tvdbId, tvdbId > 0 else {
                    print("Invalid or missing TvdbId")
                    return
                }

                viewModel.fetchQualityProfiles { profiles in
                    guard let profiles = profiles else { return }

                    let qualityPicker = QualityPicker(profiles: profiles) { selectedProfile, startDownload in
                        addingToSonarr[show.id] = true

                        var updatedShow = show.withTvdbId(tvdbId)
                        updatedShow.rootFolderPath = rootFolderPath

                        viewModel.addShow(show: updatedShow, qualityProfileId: selectedProfile.id, startDownload: startDownload) {
                            DispatchQueue.main.async {
                                addingToSonarr[show.id] = false
                                addedToSonarr[show.id] = true
                            }
                        }
                    }

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


}

