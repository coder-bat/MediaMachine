import SwiftUI
import Foundation

struct DiscoverView: View {
    @State private var popularShows: [Show] = []
    @State private var searchResults: [Show] = []
    @State private var query: String = "" // For search functionality
    @State private var addingToSonarr: [Int: Bool] = [:] // Track state by show ID
    @State private var addedToSonarr: [Int: Bool] = [:] // Track added state by show ID
    @State private var sortByHighestRating: Bool = false
    @State private var selectedFilter: DiscoverFilter = .popular
    @State private var isSidebarVisible: Bool = false
    @State private var selectedCategory: String? = nil

    @EnvironmentObject var viewModel: MediaMachineViewModel

    enum DiscoverFilter: String, CaseIterable {
        case popular = "Popular"
        case trending = "Trending"
        case topRated = "Top Rated"
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Fullscreen ShowListView
                ShowListView(currentShows: currentShows)
                
                // Sidebar overlay
                if isSidebarVisible {
                    GeometryReader { geometry in
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
                        }
                        .frame(width: geometry.size.width * 0.7) // Sidebar width (70% of screen width)
                        .background(Color(.systemGray6))
                        .shadow(radius: 10)
                        .transition(.move(edge: .leading)) // Animate the sidebar appearance
                    }
                }
            }
            .navigationTitle("Discover")
            .navigationBarItems(leading: sidebarToggleButton)
            .onChange(of: selectedFilter) { oldValue, newValue in
                fetchShows()
            }
            .onAppear {
                fetchShows()
            }
        }
    }
        
    // Sidebar Toggle Button
    private var sidebarToggleButton: some View {
        Button(action: {
            withAnimation {
                isSidebarVisible.toggle()
            }
        }) {
            SwiftUI.Image(systemName: isSidebarVisible ? "xmark" : "line.horizontal.3")
                .imageScale(.large)
        }
    }

    // MARK: - Computed Properties
    private var currentShows: [Show] {
        query.isEmpty ? sortedShows : searchResults
    }

    // MARK: - Computed Properties
    private var sortedShows: [Show] {
        sortByHighestRating
            ? popularShows.sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
            : popularShows
    }

    // MARK: - Fetch Shows
    private func fetchShows() {
//        let env = DotEnv(withFile: ".env")
        let envDict = Bundle.main.infoDictionary?["LSEnvironment"] as! Dictionary<String, String>
        guard let apiKey = envDict["TMDB_API_KEY"] else {
            print("TMDB_API_KEY not found in environment variables.", ProcessInfo.processInfo.environment)
            return
        }
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

            do {
                let decodedResponse = try JSONDecoder().decode(DiscoverResponse.self, from: data)
                DispatchQueue.main.async {
                    self.popularShows = decodedResponse.results
                    self.searchResults = decodedResponse.results
                }
            } catch {
                print("Failed to decode response: \(error.localizedDescription)")
            }
        }.resume()
    }

    // MARK: - Search Shows
    private func searchShows()
{
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

                do {
                    let decodedResponse = try JSONDecoder().decode([Show].self, from: data)
                    DispatchQueue.main.async {
                        self.searchResults = decodedResponse.filter { $0.id != -1 }
                    }
                } catch {
                    print("Failed to decode search results: \(error.localizedDescription)")
                }
            }.resume()
        }

    // MARK: - Add Show to Sonarr
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

    // MARK: - Open in Sonarr
    func openShowInSonarr(tvdbId: Int) {
//        ShowDetailView(show: nil, discoverShow: show)
        guard let serverURL = viewModel.publicServerURL else { return }
        let showURL = "\(serverURL)/series/\(tvdbId)"
        if let url = URL(string: showURL) {
            UIApplication.shared.open(url)
        }
    }
}
