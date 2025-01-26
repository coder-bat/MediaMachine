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

    @State private var hoveredShowId: Int?
    @State private var page: Int = 1
    @State private var isLoading: Bool = false
    @State private var hasMoreContent: Bool = true
    @State private var allShows: [Show]
    @EnvironmentObject var viewModel: MediaMachineViewModel
    @State private var addingToSonarr: [Int: Bool] = [:]
    @State private var addedToSonarr: [Int: Bool] = [:]
    @Environment(\.disableInfiniteScroll) var disableInfiniteScroll

    init(currentShows: [Show]) {
        self.currentShows = currentShows
        _allShows = State(initialValue: currentShows)
    }

    var body: some View {
        let columns = [
            GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 20)
        ]

        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(Array(allShows.enumerated()), id: \.offset) { index, show in
                    NavigationLink(destination: ShowDetailView(show: show)) {
                        ShowCard(show: show,
                               isHovered: hoveredShowId == show.id,
                               addingToSonarr: $addingToSonarr,
                               addedToSonarr: $addedToSonarr,
                               viewModel: viewModel)
                            .onHover { isHovered in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    hoveredShowId = isHovered ? show.id : nil
                                }
                            }
                            .onAppear {
                                if !disableInfiniteScroll &&
                                    index == allShows.count - 1 &&
                                    !isLoading &&
                                    hasMoreContent {
                                    loadMoreContent()
                                }
                            }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()

            if !disableInfiniteScroll && isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .onAppear {
            allShows = currentShows
        }
    }

    private func loadMoreContent() {
        guard !isLoading && hasMoreContent else { return }

        isLoading = true
        let nextPage = page + 1

        fetchMoreShows(page: nextPage) { newShows in
            DispatchQueue.main.async {
                if !newShows.isEmpty {
                    allShows.append(contentsOf: newShows)
                    page = nextPage
                } else {
                    hasMoreContent = false
                }
                isLoading = false
            }
        }
    }

    private func fetchMoreShows(page: Int, completion: @escaping ([Show]) -> Void) {
        let envDict = Bundle.main.infoDictionary?["LSEnvironment"] as! Dictionary<String, String>
        guard let apiKey = envDict["TMDB_API_KEY"] else {
            print("TMDB_API_KEY not found in environment variables.")
            completion([])
            return
        }

        // Determine the endpoint based on the current shows being displayed
        // You might need to pass this information through a parameter
        let endpoint = "popular" // Default to popular, adjust as needed
        let urlString = "https://api.themoviedb.org/3/tv/\(endpoint)?api_key=\(apiKey)&language=en-US&page=\(page)"

        guard let url = URL(string: urlString) else {
            completion([])
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching more shows: \(error)")
                completion([])
                return
            }

            guard let data = data else {
                completion([])
                return
            }

            do {
                let decodedResponse = try JSONDecoder().decode(DiscoverResponse.self, from: data)
                completion(decodedResponse.results)
            } catch {
                print("Failed to decode response: \(error)")
                completion([])
            }
        }.resume()
    }
}

private struct ShowCard: View {
    let show: Show
    let isHovered: Bool
    @Binding var addingToSonarr: [Int: Bool]
    @Binding var addedToSonarr: [Int: Bool]
    let viewModel: MediaMachineViewModel

    var body: some View {
        HStack(spacing: 15) {
            // Poster Image
            let posterURL = show.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" } ?? show.posterUrl

            if let posterURL = posterURL, let url = URL(string: posterURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 150)
                        .overlay(ProgressView().tint(.white))
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 150)
                    .overlay(
                        Text("No Image")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            }

            // Show Details
            VStack(alignment: .leading, spacing: 8) {
                Text(show.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(2)

                if let status = show.status?.capitalized {
                    Text(status)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                }

                if let releaseDate = show.firstAirDate {
                    Text("Released: \(releaseDate)")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                }

                if let rating = show.voteAverage {
                    HStack(spacing: 4) {
                        SwiftUI.Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(rating, specifier: "%.1f")/10")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                }

                if show.monitored == nil {
                    Button(action: {
                        if addedToSonarr[show.id] == true {
                            openShowInSonarr(tvdbId: show.id)
                        } else {
                            addShowToSonarr(show)
                        }
                    }) {
                        Text(buttonTitle(for: show))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .scaleEffect(isHovered ? 1.05 : 1.0)
                    }
                    .disabled(addingToSonarr[show.id] == true)
                } else {
                    Text(show.monitored == true ? "Monitored" : "Not Monitored")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(show.monitored == true ? .green : .red)
                }
            }
            .padding(.vertical, 10)

            Spacer()
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.secondarySystemBackground))
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: isHovered ? 10 : 5,
                    x: 0,
                    y: isHovered ? 5 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(isHovered ? 0.5 : 0), .purple.opacity(isHovered ? 0.5 : 0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
    }

    private func buttonTitle(for show: Show) -> String {
        if addedToSonarr[show.id] == true {
            return "👀 View in Sonarr"
        } else if addingToSonarr[show.id] == true {
            return "Adding..."
        } else {
            return "⊕ Add to Sonarr"
        }
    }

    private func openShowInSonarr(tvdbId: Int) {
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
