import SwiftUI

struct DiscoverView: View {
    @State private var popularShows: [DiscoverShow] = []
    @State private var searchResults: [DiscoverShow] = []
    @State private var query: String = "" // For search functionality
    @State private var addingToSonarr: [Int: Bool] = [:] // Track state by show ID
    @State private var addedToSonarr: [Int: Bool] = [:] // Track added state by show ID
    @State private var sortByHighestRating: Bool = false
    @State private var selectedFilter: DiscoverFilter = .popular

    @EnvironmentObject var viewModel: SonarrPlusViewModel
    
    enum DiscoverFilter: String, CaseIterable {
        case popular = "Popular"
        case trending = "Trending"
        case topRated = "Top Rated"
    }

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                TextField("Search for shows...", text: $query, onCommit: {
                    searchShows()
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(DiscoverFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Show List
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(currentShows, id: \.id) { show in
                            VStack {
                                // Show Poster
                                if let posterPath = show.posterPath {
                                    let fullPosterPath = "https://image.tmdb.org/t/p/w500\(posterPath)"
                                    AsyncImage(url: URL(string: fullPosterPath)) { image in
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .cornerRadius(8)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 200)
                                            .cornerRadius(8)
                                    }
                                } else if let posterUrl = show.posterUrl {
                                    AsyncImage(url: URL(string: posterUrl)) { image in
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .cornerRadius(8)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 200)
                                            .cornerRadius(8)
                                    }
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 200)
                                        .overlay(
                                            Text("No Image")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        )
                                        .cornerRadius(8)
                                }
                                
                                // Show Title
                                Text(show.name)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .padding(.vertical, 5)

                                // Release Date and Ratings
                                if let releaseDate = show.firstAirDate {
                                    Text("Released: \(releaseDate)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let rating = show.voteAverage {
                                    Text("Rating: \(rating, specifier: "%.1f")/10")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Add Button
                                Button(action: {
                                    if addedToSonarr[show.id] == true {
                                        openShowInSonarr(tvdbId: show.tvdbId ?? 0)
                                    } else {
                                        addShowToSonarr(show)
                                    }
                                }) {
                                    Text(addedToSonarr[show.id] == true ? "View in Sonarr" : (addingToSonarr[show.id] == true ? "Adding..." : "Add to Sonarr"))
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 5)
                                .disabled(addingToSonarr[show.id] == true)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Discover")
            .onChange(of: selectedFilter) {
                fetchShows()
            }
            .onAppear {
                fetchShows()
            }
        }
    }

    // MARK: - Computed Properties
    private var currentShows: [DiscoverShow] {
        query.isEmpty ? sortedShows : searchResults
    }

    // MARK: - Computed Properties
    private var sortedShows: [DiscoverShow] {
        sortByHighestRating
            ? popularShows.sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
            : popularShows
    }

    // MARK: - Fetch Shows
    private func fetchShows() {
        let apiKey = ""
        let endpoint: String

        switch selectedFilter {
        case .popular:
            endpoint = "popular"
        case .trending:
            endpoint = "on_the_air"
        case .topRated:
            endpoint = "top_rated"
        }

        let urlString = "https://api.themoviedb.org/3/tv/\(endpoint)?api_key=\(apiKey)&language=en-US&page=1"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Failed to fetch shows: \(error.localizedDescription)")
                return
            }

            guard let data = data else { return }
            
            // Log the raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON response: \(jsonString)")
            }

            do {
                let decodedResponse = try JSONDecoder().decode(DiscoverResponse.self, from: data)
                DispatchQueue.main.async {
                    self.popularShows = decodedResponse.results
                }
            } catch {
                print("Failed to decode response: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    // MARK: - Search Shows
    private func searchShows() {
            guard let serverURL = viewModel.publicServerURL, let apiKey = viewModel.publicApiKey else {
                print("Server URL or API Key is missing")
                return
            }

            let urlString = "\(serverURL)/api/v3/series/lookup?term=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&apikey=\(apiKey)"
            guard let url = URL(string: urlString) else { return }

            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("Search error: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    print("No data received from API.")
                    return
                }
                
                // Log the raw response
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON response: \(jsonString)")
                }

                do {
                    let decodedResponse = try JSONDecoder().decode([DiscoverShow].self, from: data)
                    DispatchQueue.main.async {
                        self.searchResults = decodedResponse.filter { $0.id != -1 }
                    }
                } catch {
                    print("Failed to decode search results: \(error.localizedDescription)")
                }
            }.resume()
        }

    // MARK: - Add Show to Sonarr
    private func addShowToSonarr(_ show: DiscoverShow) {
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

    // MARK: - Open in Sonarr
    private func openShowInSonarr(tvdbId: Int) {
        guard let serverURL = viewModel.publicServerURL else { return }
        let showURL = "\(serverURL)/series/\(tvdbId)"
        if let url = URL(string: showURL) {
            UIApplication.shared.open(url)
        }
    }
}
