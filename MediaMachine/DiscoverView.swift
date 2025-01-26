import SwiftUI
import Foundation

private struct SearchResultShow: Identifiable {
    let show: Show
    let uniqueId: Int

    var id: Int { uniqueId }

    init(show: Show, index: Int) {
        self.show = show
        self.uniqueId = show.id * 10000 + index
    }
}

class WatchlistManager: ObservableObject {
    @Published var watchlist: [Show] = []

    func addToWatchlist(_ show: Show) {
        if !watchlist.contains(where: { $0.id == show.id }) {
            watchlist.append(show)
        }
    }

    func removeFromWatchlist(_ show: Show) {
        watchlist.removeAll(where: { $0.id == show.id })
    }
}

struct DiscoverView: View {
    @State private var popularShows: [Show] = []
    @State private var trendingShows: [Show] = []
    @State private var topRatedShows: [Show] = []
    @State private var dramaShows: [Show] = []
    @State private var comedyShows: [Show] = []
    @State private var actionAdventureShows: [Show] = []
    @State private var sciFiFantasyShows: [Show] = []
    @State private var crimeShows: [Show] = []
    @State private var mysteryShows: [Show] = []
    @State private var animationShows: [Show] = []
    @State private var familyShows: [Show] = []
    @State private var documentaryShows: [Show] = []
    @State private var realityShows: [Show] = []
    @State private var searchResults: [SearchResultShow] = []
    @State private var query: String = ""
    @State private var addingToSonarr: [Int: Bool] = [:]
    @State private var addedToSonarr: [Int: Bool] = [:]
    @State private var sortByHighestRating: Bool = false
    @State private var selectedFilter: DiscoverFilter = .popular
    @State private var selectedCategory: String? = nil
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>?
    @State private var searchDebounceTimer: Timer?
    @State private var showingCategorySelection = false
    @StateObject private var watchlistManager = WatchlistManager()
    @State private var showingWatchlist = false

    @EnvironmentObject var viewModel: MediaMachineViewModel

    enum DiscoverFilter: String, CaseIterable {
        case popular = "Popular"
        case trending = "Trending"
        case topRated = "Top Rated"
    }

    var body: some View {
        NavigationView {
            ZStack {
                contentView

                // Floating Buttons
                VStack {
                    Spacer()
                    HStack {
                        // Watchlist Button
                        Button(action: {
                            showingWatchlist = true
                        }) {
                            HStack {
                                SwiftUI.Image(systemName: "list.star")
                                Text("Watchlist")
                            }
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }

                        // Help Me Pick Button
                        Button(action: {
                            showingCategorySelection = true
                        }) {
                            HStack {
                                SwiftUI.Image(systemName: "wand.and.stars")
                                Text("Help Me Pick")
                            }
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30) // Add bottom padding
                }
            }
            .sheet(isPresented: $showingWatchlist) {
                WatchlistView(watchlistManager: watchlistManager)
            }
            .sheet(isPresented: $showingCategorySelection) {
                CategorySelectionView(watchlistManager: watchlistManager)
            }
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                contentStack
            }
        }
        .onAppear {
            fetchAllCategories()
        }
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 20) {
            trendingSection
            popularSection
            topRatedSection
            dramaSection
            comedySection
            actionSection
            sciFiSection
            crimeSection
            mysterySection
            animationSection
            familySection
            documentarySection
            realitySection
        }
        .padding()
    }

    private var trendingSection: some View {
        ShowCarousel(title: "Trending", shows: trendingShows)
    }

    private var popularSection: some View {
        ShowCarousel(title: "Popular", shows: popularShows)
    }

    private var topRatedSection: some View {
        ShowCarousel(title: "Top Rated", shows: topRatedShows)
    }

    private var dramaSection: some View {
        ShowCarousel(title: "Drama", shows: dramaShows)
    }

    private var comedySection: some View {
        ShowCarousel(title: "Comedy", shows: comedyShows)
    }

    private var actionSection: some View {
        ShowCarousel(title: "Action & Adventure", shows: actionAdventureShows)
    }

    private var sciFiSection: some View {
        ShowCarousel(title: "Sci-Fi & Fantasy", shows: sciFiFantasyShows)
    }

    private var crimeSection: some View {
        ShowCarousel(title: "Crime", shows: crimeShows)
    }

    private var mysterySection: some View {
        ShowCarousel(title: "Mystery", shows: mysteryShows)
    }

    private var animationSection: some View {
        ShowCarousel(title: "Animation", shows: animationShows)
    }

    private var familySection: some View {
        ShowCarousel(title: "Family", shows: familyShows)
    }

    private var documentarySection: some View {
        ShowCarousel(title: "Documentary", shows: documentaryShows)
    }

    private var realitySection: some View {
        ShowCarousel(title: "Reality", shows: realityShows)
    }

    // MARK: - Computed Properties
    private var currentShows: [Show] {
        query.isEmpty ? sortedShows : searchResults.map(\.show)
    }

    // MARK: - Computed Properties
    private var sortedShows: [Show] {
        sortByHighestRating
            ? popularShows.sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
            : popularShows
    }

    // MARK: - Fetch Shows
    private func fetchAllCategories() {
        fetchShows(for: .trending) { shows in
            self.trendingShows = shows
        }
        fetchShows(for: .popular) { shows in
            self.popularShows = shows
        }
        fetchShows(for: .topRated) { shows in
            self.topRatedShows = shows
        }
        fetchShowsByGenre(genreId: 18) { shows in // Drama
            self.dramaShows = shows
        }
        fetchShowsByGenre(genreId: 35) { shows in // Comedy
            self.comedyShows = shows
        }
        fetchShowsByGenre(genreId: 10759) { shows in // Action & Adventure
            self.actionAdventureShows = shows
        }
        fetchShowsByGenre(genreId: 10765) { shows in // Sci-Fi & Fantasy
            self.sciFiFantasyShows = shows
        }
        fetchShowsByGenre(genreId: 80) { shows in // Crime
            self.crimeShows = shows
        }
        fetchShowsByGenre(genreId: 9648) { shows in // Mystery
            self.mysteryShows = shows
        }
        fetchShowsByGenre(genreId: 16) { shows in // Animation
            self.animationShows = shows
        }
        fetchShowsByGenre(genreId: 10751) { shows in // Family
            self.familyShows = shows
        }
        fetchShowsByGenre(genreId: 99) { shows in // Documentary
            self.documentaryShows = shows
        }
        fetchShowsByGenre(genreId: 10764) { shows in // Reality
            self.realityShows = shows
        }
    }

    private func fetchShows(for category: DiscoverFilter, completion: @escaping ([Show]) -> Void) {
        let envDict = Bundle.main.infoDictionary?["LSEnvironment"] as! Dictionary<String, String>
        guard let apiKey = envDict["TMDB_API_KEY"] else {
            print("TMDB_API_KEY not found in environment variables.")
            return
        }

        let endpoint = category.endpoint
        let urlString = "https://api.themoviedb.org/3/tv/\(endpoint)?api_key=\(apiKey)&language=en-US&page=1"

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let decodedResponse = try JSONDecoder().decode(DiscoverResponse.self, from: data)
                    DispatchQueue.main.async {
                        completion(decodedResponse.results)
                    }
                } catch {
                    print("Failed to decode response: \(error)")
                }
            }
        }.resume()
    }

    private func fetchShowsByGenre(genreId: Int, completion: @escaping ([Show]) -> Void) {
        let envDict = Bundle.main.infoDictionary?["LSEnvironment"] as! Dictionary<String, String>
        guard let apiKey = envDict["TMDB_API_KEY"] else { return }

        let urlString = "https://api.themoviedb.org/3/discover/tv?api_key=\(apiKey)&with_genres=\(genreId)"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let decodedResponse = try JSONDecoder().decode(DiscoverResponse.self, from: data)
                    DispatchQueue.main.async {
                        completion(decodedResponse.results)
                    }
                } catch {
                    print("Failed to decode response: \(error)")
                }
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
        guard let serverURL = viewModel.publicServerURL else { return }
        let showURL = "\(serverURL)/series/\(tvdbId)"
        if let url = URL(string: showURL) {
            UIApplication.shared.open(url)
        }
    }
}

// Add this extension to handle endpoints
extension DiscoverView.DiscoverFilter {
    var endpoint: String {
        switch self {
        case .popular:
            return "popular"
        case .trending:
            return "on_the_air"
        case .topRated:
            return "top_rated"
        }
    }
}

// New ShowCarousel component
struct ShowCarousel: View {
    let title: String
    let shows: [Show]
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading) {
            carouselHeader
            carouselContent
        }
        .padding(.vertical, 10)
    }

    private var carouselHeader: some View {
        HStack {
            carouselTitle
            Spacer()
            carouselSeeMoreButton
        }
        .padding(.horizontal)
    }

    private var carouselTitle: some View {
        Text(title)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

    private var carouselSeeMoreButton: some View {
        NavigationLink(destination: ShowListView(currentShows: shows)) {
            Text("See More")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .stroke(LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ), lineWidth: 2)
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
    }

    private var carouselContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 15) {
                ForEach(shows) { show in
                    NavigationLink(destination: ShowDetailView(show: show)) {
                        ShowPosterCard(show: show)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// New ShowPosterCard component
struct ShowPosterCard: View {
    let show: Show
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading) {
            let posterURL = show.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" } ?? show.posterUrl

            if let posterURL = posterURL, let url = URL(string: posterURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 180, height: 270)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(radius: isHovered ? 10 : 5)
                        .scaleEffect(isHovered ? 1.05 : 1.0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(LinearGradient(
                                    colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ), lineWidth: isHovered ? 2 : 0)
                        )
                        .overlay(
                            showTitle
                                .opacity(isHovered ? 1 : 0)
                        )
                } placeholder: {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 180, height: 270)
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                }
            } else {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 180, height: 270)
                    .overlay(
                        Text("No Image")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
    }

    private var showTitle: some View {
        VStack {
            Spacer()
            Text(show.name)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .blur(radius: 3)
                )
                .clipShape(RoundedRectangle(cornerRadius: 15))
        }
        .padding(8)
    }
}

// Add CategorySelectionView to the same file
struct CategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategories: Set<String> = []
    @ObservedObject var watchlistManager: WatchlistManager

    let categories = [
        "Drama",
        "Comedy",
        "Action & Adventure",
        "Sci-Fi & Fantasy",
        "Crime",
        "Mystery",
        "Animation",
        "Family",
        "Documentary",
        "Reality"
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                Text("What type of shows do you like?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .padding(.top)

                Text("Select multiple categories")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                // Categories Grid
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                ], spacing: 16) {
                    ForEach(categories, id: \.self) { category in
                        CategoryButton(
                            title: category,
                            isSelected: selectedCategories.contains(category),
                            action: {
                                if selectedCategories.contains(category) {
                                    selectedCategories.remove(category)
                                } else {
                                    selectedCategories.insert(category)
                                }
                            }
                        )
                    }
                }
                .padding()

                Spacer()

                // Updated Done Button
                NavigationLink(destination: ShowSwipeView(categories: selectedCategories, watchlistManager: watchlistManager)) {
                    Text("Find Shows")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
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
                .padding()
            }
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isSelected ?
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [Color(.systemGray6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

// Add this after CategorySelectionView

struct ShowSwipeView: View {
    @Environment(\.dismiss) private var dismiss
    let categories: Set<String>
    @State private var currentIndex = 0
    @State private var shows: [Show] = []
    @State private var isLoading = true
    @State private var showToast = false
    @EnvironmentObject var viewModel: MediaMachineViewModel
    @ObservedObject var watchlistManager: WatchlistManager

    private func fetchShowsForCategories() {
        let genreMap = [
            "Drama": 18,
            "Comedy": 35,
            "Action & Adventure": 10759,
            "Sci-Fi & Fantasy": 10765,
            "Crime": 80,
            "Mystery": 9648,
            "Animation": 16,
            "Family": 10751,
            "Documentary": 99,
            "Reality": 10764
        ]

        let envDict = Bundle.main.infoDictionary?["LSEnvironment"] as! Dictionary<String, String>
        guard let apiKey = envDict["TMDB_API_KEY"] else {
            print("TMDB_API_KEY not found in environment variables.")
            isLoading = false
            return
        }

        // Create a group for concurrent fetching
        let group = DispatchGroup()
        var allShows: [Show] = []

        // Fetch shows for each selected category
        for category in categories {
            if let genreId = genreMap[category] {
                group.enter()

                let urlString = "https://api.themoviedb.org/3/discover/tv?api_key=\(apiKey)&with_genres=\(genreId)"
                guard let url = URL(string: urlString) else {
                    group.leave()
                    continue
                }

                URLSession.shared.dataTask(with: url) { data, response, error in
                    defer { group.leave() }

                    if let data = data {
                        do {
                            let decodedResponse = try JSONDecoder().decode(DiscoverResponse.self, from: data)
                            DispatchQueue.main.async {
                                allShows.append(contentsOf: decodedResponse.results)
                            }
                        } catch {
                            print("Failed to decode response: \(error)")
                        }
                    }
                }.resume()
            }
        }

        // When all fetches are complete
        group.notify(queue: .main) {
            // Remove duplicates by ID and shuffle
            var uniqueShows: [Show] = []
            var seenIds = Set<Int>()

            for show in allShows {
                if !seenIds.contains(show.id) {
                    uniqueShows.append(show)
                    seenIds.insert(show.id)
                }
            }

            shows = uniqueShows.shuffled()
            isLoading = false
        }
    }

    var body: some View {
        ZStack {
            if isLoading {
                loadingView
            } else if shows.isEmpty {
                noShowsView
            } else {
                mainView
            }

            // Toast Notification
            if showToast {
                VStack {
                    Spacer()
                    HStack {
                        SwiftUI.Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Added to Watchlist")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .clipShape(Capsule())
                    .transition(.move(edge: .bottom))
                    .padding(.bottom, 100) // Position above buttons
                }
                .zIndex(1) // Ensure toast appears above other content
            }
        }
        .onAppear {
            fetchShowsForCategories()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Finding shows for you...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
        }
    }

    private var noShowsView: some View {
        VStack(spacing: 20) {
            SwiftUI.Image(systemName: "tv.slash")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("No shows found")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Button("Go Back") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var mainView: some View {
        VStack(spacing: 20) {
            if currentIndex < shows.count {
                cardView(for: shows[currentIndex])
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                HStack(spacing: 40) {
                    Button {
                        withAnimation {
                            nextShow()
                        }
                    } label: {
                        SwiftUI.Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.red.opacity(0.7))
                            .background(Circle().fill(Color.white).shadow(radius: 5))
                    }

                    NavigationLink(destination: ShowDetailView(show: shows[currentIndex])) {
                        SwiftUI.Image(systemName: "info.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.blue.opacity(0.7))
                            .background(Circle().fill(Color.white).shadow(radius: 5))
                    }

                    Button {
                        withAnimation {
                            watchlistManager.addToWatchlist(shows[currentIndex])
                            showToast = true
                            // Hide toast after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showToast = false
                                }
                            }
                            nextShow()
                        }
                    } label: {
                        SwiftUI.Image(systemName: "heart.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green.opacity(0.7))
                            .background(Circle().fill(Color.white).shadow(radius: 5))
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }

    private func cardView(for show: Show) -> some View {
        let posterURL = show.posterPath.map { "https://image.tmdb.org/t/p/w780\($0)" } ?? show.posterUrl

        return ZStack(alignment: .bottom) {
            if let posterURL = posterURL, let url = URL(string: posterURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.5)
                        )
                }
            }

            // Show info overlay
            VStack(alignment: .leading, spacing: 8) {
                Text(show.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let rating = show.voteAverage {
                    HStack {
                        SwiftUI.Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.7), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 10)
    }

    private func nextShow() {
        if currentIndex < shows.count - 1 {
            currentIndex += 1
        } else {
            // No more shows, dismiss the view
            dismiss()
        }
    }
}

// WatchlistView components
struct WatchlistItemView: View {
    let show: Show

    var body: some View {
        HStack {
            PosterThumbnail(posterPath: show.posterPath)
            ShowInfo(show: show)
        }
    }
}

struct PosterThumbnail: View {
    let posterPath: String?

    var body: some View {
        AsyncImage(url: URL(string: posterPath.map { "https://image.tmdb.org/t/p/w154\($0)" } ?? "")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50)
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 75)
        }
    }
}

struct ShowInfo: View {
    let show: Show

    var body: some View {
        VStack(alignment: .leading) {
            Text(show.name)
                .font(.headline)
            if let rating = show.voteAverage {
                HStack {
                    SwiftUI.Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", rating))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// Updated WatchlistView
struct WatchlistView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var watchlistManager: WatchlistManager

    var body: some View {
        NavigationView {
            List {
                ForEach(watchlistManager.watchlist) { show in
                    NavigationLink(destination: ShowDetailView(show: show)) {
                        WatchlistItemView(show: show)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        watchlistManager.removeFromWatchlist(watchlistManager.watchlist[index])
                    }
                }
            }
            .navigationTitle("My Watchlist")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}
