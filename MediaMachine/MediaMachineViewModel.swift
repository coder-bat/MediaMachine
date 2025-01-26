//
//  MediaMachineViewModel.swift
//  MediaMachine
//
//  Created by Coder Bat on 12/1/2025.
//

import Foundation
import Combine

class MediaMachineViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var rootFolderPath: String? // To store the selected root folder path
    @Published var stats: SonarrStats?
    @Published var downloadQueue: [DownloadItem] = []
    @Published var hasIndexers: Bool = false

    static let shared = MediaMachineViewModel()

    @Published var shows: [Show] = [] {
        didSet {
            saveNotificationPreferences()
        }
    }

    private let notificationsKey = "NotificationPreferences"

    private init() { // Private initializer
        loadNotificationPreferences()
        fetchRootFolders()
    }

    func saveNotificationPreferences() {
        let preferences = shows.reduce(into: [String: Bool]()) { dict, show in
            dict["\(show.id)"] = show.notificationsEnabled
        }
        UserDefaults.standard.set(preferences, forKey: notificationsKey)
        UserDefaults.standard.synchronize()
    }

    func loadNotificationPreferences() {
        let preferences = UserDefaults.standard.dictionary(forKey: notificationsKey) as? [String: Bool] ?? [:]
        shows = shows.map { show in
            var updatedShow = show
            if let isEnabled = preferences["\(show.id)"] {
                updatedShow.notificationsEnabled = isEnabled
            }
            return updatedShow
        }
    }


    private var cancellables = Set<AnyCancellable>()
    private var serverURL: String?
    private var apiKey: String?

    // Public getters
   var publicServerURL: String? {
       return serverURL
   }

   var publicApiKey: String? {
       return apiKey
   }

//    var publicRootFolderPath: String {
//        return rootFolderPath // Assuming `rootFolderPath` is already defined in the class
//    }


    func authenticateWithApiKey(serverURL: String, apiKey: String, completion: @escaping (Bool, String?) -> Void) {
        self.serverURL = serverURL
        self.apiKey = apiKey


        guard let testURL = URL(string: "\(serverURL)/api/v3/system/status?apikey=\(apiKey)") else {
            completion(false, "Invalid server URL.")
            return
        }

        URLSession.shared.dataTask(with: testURL) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "Network error: \(error.localizedDescription)")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    completion(false, "Invalid API key or server response.")
                }
                return
            }

            DispatchQueue.main.async {
                self.isAuthenticated = true
                completion(true, nil)
            }
        }.resume()
    }



    func fetchShows() {
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else { return }

        let url = URL(string: "\(serverURL)/api/v3/series?apikey=\(apiKey)")!

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Failed to fetch shows: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            do {
                let shows = try JSONDecoder().decode([Show].self, from: data)
                DispatchQueue.main.async {
                    self.shows = shows
                }
            } catch {
                print("Failed to decode shows: \(error.localizedDescription)")
            }
        }.resume()
    }

    func fetchEpisodes(for show: Show, completion: @escaping (Result<[Episode], Error>) -> Void) {
        guard let baseURL = publicServerURL, let apiKey = publicApiKey else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing Sonarr configuration"])))
            return
        }

        let urlString = "\(baseURL)/api/v3/episode"
        guard var urlComponents = URLComponents(string: urlString) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "seriesId", value: String(show.id))
        ]

        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create URL"])))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }

                do {
                    var episodes = try JSONDecoder().decode([Episode].self, from: data)
                    // Ensure seriesId is set correctly for each episode
                    episodes = episodes.map { episode in
                        var updatedEpisode = episode
                        updatedEpisode.seriesId = show.id
                        return updatedEpisode
                    }
                    completion(.success(episodes))
                } catch {
                    print("Error decoding episodes: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Received JSON: \(jsonString)")
                    }
                    completion(.failure(error))
                }
            }
        }.resume()
    }


    func checkForUpcomingEpisodes() {
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else { return }

        let showsToNotify = shows.filter { $0.notificationsEnabled ?? false } // Filter enabled shows

        for show in showsToNotify {
            let episodesURL = URL(string: "\(serverURL)/api/v3/episode?seriesId=\(show.id)&apikey=\(apiKey)")!

            URLSession.shared.dataTask(with: episodesURL) { data, response, error in
                if let error = error {
                    print("Failed to fetch episodes for show \(show.title): \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    print("No data received for episodes")
                    return
                }

                do {
                    let episodes = try JSONDecoder().decode([Episode].self, from: data)

                    let upcomingEpisodes = episodes.filter { episode in
                        if let airDate = ISO8601DateFormatter().date(from: episode.airDate ?? "") {
                            return airDate.timeIntervalSinceNow < 24 * 60 * 60 && airDate.timeIntervalSinceNow > 0
                        }
                        return false
                    }

                    for episode in upcomingEpisodes {
                        if let airDate = ISO8601DateFormatter().date(from: episode.airDate ?? "") {
                            var updatedEpisode = episode
                            updatedEpisode.showTitle = show.title
                            NotificationManager.shared.scheduleNotification(for: updatedEpisode, airDate: airDate)
                        }
                    }
                } catch {
                    print("Failed to decode episodes: \(error.localizedDescription)")
                }
            }.resume()
        }
    }

    func fetchLibrary() {
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else { return }

        let urlString = "\(serverURL)/api/v3/series?apikey=\(apiKey)"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Failed to fetch library: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received from server")
                return
            }
            print(String(data: data, encoding: .utf8) ?? "No data returned")

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let shows = try decoder.decode([Show].self, from: data)
                DispatchQueue.main.async {
                    self.shows = shows
                }
            } catch {
                print("Failed to decode shows: \(error.localizedDescription)")
            }
        }.resume()
    }



    func fetchRootFolders() {
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else { return }

        let urlString = "\(serverURL)/api/v3/rootfolder?apikey=\(apiKey)"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Failed to fetch root folders: \(error.localizedDescription)")
                return
            }

            guard let data = data else { return }

            do {
                let rootFolders = try JSONDecoder().decode([RootFolder].self, from: data)
                DispatchQueue.main.async {
                    self.rootFolderPath = rootFolders.first?.path // Select the first root folder
                }
            } catch {
                print("Failed to decode root folders: \(error.localizedDescription)")
            }
        }.resume()
    }

    func fetchQualityProfiles(completion: @escaping ([QualityProfile]?) -> Void) {
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else { return }
        let urlString = "\(serverURL)/api/v3/qualityprofile?apikey=\(apiKey)"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Failed to fetch quality profiles: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else { return }

            do {
                let profiles = try JSONDecoder().decode([QualityProfile].self, from: data)
                completion(profiles)
            } catch {
                print("Failed to decode quality profiles: \(error.localizedDescription)")
                completion(nil)
            }
        }.resume()
    }


    func addShow(show: Show, qualityProfileId: Int, startDownload: Bool, completion: @escaping () -> Void) {
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else { return }

        let urlString = "\(serverURL)/api/v3/series"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            var showToAdd = show.toSonarrModel(rootFolderPath: rootFolderPath ?? "")
            showToAdd.qualityProfileId = qualityProfileId
            showToAdd.addOptions = AddOptions(searchForMissingEpisodes: startDownload)

            let bodyData = try JSONEncoder().encode(showToAdd)
            request.httpBody = bodyData
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

            URLSession.shared.dataTask(with: request) { data, response, error in
                completion()
            }.resume()

        } catch {
            print("Failed to encode show: \(error.localizedDescription)")
        }
    }

    func fetchRootFolders(completion: @escaping ([String]?) -> Void) {
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else {
            print("Server URL or API Key is missing")
            completion(nil)
            return
        }

        let urlString = "\(serverURL)/api/v3/rootfolder"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to fetch root folders: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                completion(nil)
                return
            }

            do {
                struct RootFolder: Codable {
                    let path: String
                }
                let rootFolders = try JSONDecoder().decode([RootFolder].self, from: data)
                completion(rootFolders.map { $0.path })
            } catch {
                print("Failed to decode root folders: \(error.localizedDescription)")
                completion(nil)
            }
        }.resume()
    }



    func fetchTvdbId(for showTitle: String, completion: @escaping (Int?) -> Void) {
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else { return }
        let urlString = "\(serverURL)/api/v3/series/lookup?term=\(showTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to fetch TvdbId: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                completion(nil)
                return
            }

            do {
                struct Series: Codable {
                    let tvdbId: Int?
                }
                let series = try JSONDecoder().decode([Series].self, from: data)
                completion(series.first?.tvdbId)
            } catch {
                print("Failed to decode series lookup: \(error.localizedDescription)")
                completion(nil)
            }
        }.resume()
    }

    func fetchStats() async {
        do {
            let totalShows = try await fetchTotalShows()
            let (disks, diskSpaceUsed, diskSpaceFree) = try await fetchDiskSpace()
            DispatchQueue.main.async {
                self.stats = SonarrStats(
                    totalShows: totalShows,
                    totalEpisodes: 0, // Optional to calculate from another endpoint
                    diskSpaceUsed: diskSpaceUsed,
                    diskSpaceFree: diskSpaceFree,
                    disks: disks
                )
            }
        } catch {
            print("Error fetching stats: \(error)")
        }
    }

    private func fetchTotalShows() async throws -> Int {
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else { return 0 }
        guard let url = URL(string: "\(serverURL)/api/v3/series") else { return 0 }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        let (data, _) = try await URLSession.shared.data(for: request)
        let series = try JSONDecoder().decode([Series].self, from: data)
        return series.count
    }

    private func fetchDiskSpace() async throws -> ([DiskSpace], Double, Double) {
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else { return ([], 0, 0) }
        guard let url = URL(string: "\(serverURL)/api/v3/diskspace") else { return ([], 0, 0) }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        let (data, _) = try await URLSession.shared.data(for: request)
        let disks = try JSONDecoder().decode([DiskSpace].self, from: data)
        //        Aggregate free and used space across all disks
        let totalUsedSpace = disks.reduce(0) { $0 + $1.usedSpace }
        let totalFreeSpace = disks.reduce(0) { $0 + $1.freeSpace }

        // Convert bytes to GB
        return (disks, totalUsedSpace / 1_073_741_824, totalFreeSpace / 1_073_741_824)
    }

    func fetchDownloadQueue() async {
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else { return }
        guard let url = URL(string: "\(serverURL)/api/v3/queue") else { return }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            // Decode the wrapped response
            let decodedResponse = try JSONDecoder().decode(DownloadQueueResponse.self, from: data)
            DispatchQueue.main.async {
                self.downloadQueue = decodedResponse.records
            }
        } catch {
            print("Error fetching download queue: \(error)")
        }
    }


    func cancelDownload(id: Int) async {
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else { return }
        guard let url = URL(string: "\(serverURL)/api/v3/queue/\(id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    self.downloadQueue.removeAll { $0.id == id }
                }
            } else {
                print("Failed to cancel download: \(response)")
            }
        } catch {
            print("Error canceling download: \(error)")
        }
    }

    private func getTodayISODate() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }

    func updateSeasonMonitoring(showId: Int, seasonNumber: Int, monitored: Bool, completion: @escaping (Bool) -> Void) {
        guard let baseURL = publicServerURL, let apiKey = publicApiKey else { return }

        // First get the series data
        let urlString = "\(baseURL)/api/v3/series/\(showId)"
        guard var urlComponents = URLComponents(string: urlString) else {
            print("Invalid URL")
            completion(false)
            return
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        guard let url = urlComponents.url else {
            print("Failed to create URL")
            completion(false)
            return
        }

        // First GET the series
        var getRequest = URLRequest(url: url)
        getRequest.httpMethod = "GET"

        URLSession.shared.dataTask(with: getRequest) { data, response, error in
            guard let data = data else {
                print("No series data received")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            do {
                // Decode the current series
                var series = try JSONDecoder().decode(Show.self, from: data)

                // Update the season monitoring
                if var seasons = series.seasons {
                    for i in 0..<seasons.count {
                        if seasons[i].seasonNumber == seasonNumber {
                            seasons[i].monitored = monitored
                            break
                        }
                    }
                    series.seasons = seasons
                }

                // Create PUT request with updated series
                var putRequest = URLRequest(url: url)
                putRequest.httpMethod = "PUT"
                putRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

                // Encode the entire updated series
                let updatedData = try JSONEncoder().encode(series)
                putRequest.httpBody = updatedData

                print("Sending update request for season \(seasonNumber) with monitored = \(monitored)")
                if let requestBody = String(data: updatedData, encoding: .utf8) {
                    print("Request body: \(requestBody)")
                }

                // Send the PUT request
                URLSession.shared.dataTask(with: putRequest) { data, response, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Error updating series: \(error)")
                            completion(false)
                            return
                        }

                        guard let httpResponse = response as? HTTPURLResponse else {
                            print("Invalid response")
                            completion(false)
                            return
                        }

                        let success = httpResponse.statusCode == 200 || httpResponse.statusCode == 202
                        print("Series update status code: \(httpResponse.statusCode)")

                        if !success {
                            if let responseData = data, let responseStr = String(data: responseData, encoding: .utf8) {
                                print("Error response: \(responseStr)")
                            }
                        }

                        completion(success)
                    }
                }.resume()

            } catch {
                print("Error processing series: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Received JSON: \(jsonString)")
                }
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }

    func updateEpisodeMonitoring(episodeId: Int, monitored: Bool, completion: @escaping (Bool) -> Void) {
        guard let baseURL = publicServerURL, let apiKey = publicApiKey else { return }

        let urlString = "\(baseURL)/api/v3/episode/monitor"
        guard var urlComponents = URLComponents(string: urlString) else {
            completion(false)
            return
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        guard let url = urlComponents.url else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let updateData = [
            "episodeIds": [episodeId],
            "monitored": monitored
        ] as [String : Any]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)

            print("Sending update request for episode \(episodeId) with monitored = \(monitored)")
            if let requestBody = String(data: request.httpBody!, encoding: .utf8) {
                print("Request body: \(requestBody)")
            }
        } catch {
            print("Error encoding update data: \(error)")
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error updating episode \(episodeId): \(error)")
                    completion(false)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response for episode \(episodeId)")
                    completion(false)
                    return
                }

                let success = httpResponse.statusCode == 200 || httpResponse.statusCode == 202
                print("Episode \(episodeId) update status code: \(httpResponse.statusCode)")

                if !success {
                    if let responseData = data, let responseStr = String(data: responseData, encoding: .utf8) {
                        print("Error response for episode \(episodeId): \(responseStr)")
                    }
                }

                completion(success)
            }
        }.resume()
    }

    func searchEpisode(episodeId: Int, completion: @escaping (Bool) -> Void) {
        guard let baseURL = publicServerURL, let apiKey = publicApiKey else { return }

        let urlString = "\(baseURL)/api/v3/command"
        guard var urlComponents = URLComponents(string: urlString) else {
            completion(false)
            return
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        guard let url = urlComponents.url else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let commandData = [
            "name": "EpisodeSearch",
            "episodeIds": [episodeId]
        ] as [String : Any]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: commandData)
        } catch {
            print("Error encoding command data: \(error)")
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error searching episode: \(error)")
                    completion(false)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false)
                    return
                }

                completion(httpResponse.statusCode == 200 || httpResponse.statusCode == 201)
            }
        }.resume()
    }

    func deleteEpisodeFile(episodeId: Int, completion: @escaping (Bool) -> Void) {
        guard let baseURL = publicServerURL, let apiKey = publicApiKey else { return }

        let urlString = "\(baseURL)/api/v3/episodefile/\(episodeId)"
        guard var urlComponents = URLComponents(string: urlString) else {
            completion(false)
            return
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        guard let url = urlComponents.url else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error deleting episode file: \(error)")
                    completion(false)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false)
                    return
                }

                completion(httpResponse.statusCode == 200 || httpResponse.statusCode == 202)
            }
        }.resume()
    }

    // Add this function to check indexers
    func checkIndexers() {
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else { return }

        let urlString = "\(serverURL)/api/v3/indexer"
        guard var urlComponents = URLComponents(string: urlString) else {
            hasIndexers = false
            return
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        guard let url = urlComponents.url else {
            hasIndexers = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let indexers = try? JSONDecoder().decode([Indexer].self, from: data) else {
                    self?.hasIndexers = false
                    return
                }
                
                print("Indexers: \(indexers) \(indexers.contains { $0.enable })")

                // Check if there are any enabled indexers
                self?.hasIndexers = indexers.contains { $0.enable }
            }
        }.resume()
    }
}

// Add this struct to decode indexer response
struct Indexer: Codable {
    let enable: Bool

    enum CodingKeys: String, CodingKey {
        case enable
    }
}
