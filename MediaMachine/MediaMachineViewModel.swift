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
        guard let serverURL = serverURL, let apiKey = apiKey else {
            print("Server URL or API Key is missing")
            return
        }

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

    func fetchEpisodes(forSeason seasonNumber: Int, show: Show, completion: @escaping ([Episode]) -> Void) {
        guard let serverURL = serverURL, let apiKey = apiKey else {
            print("Server URL or API Key is missing")
            completion([])
            return
        }

        let url = URL(string: "\(serverURL)/api/v3/episode?seriesId=\(show.id)&seasonNumber=\(seasonNumber)&apikey=\(apiKey)")!

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Failed to fetch episodes: \(error.localizedDescription)")
                completion([])
                return
            }

            guard let data = data else {
                print("No data received")
                completion([])
                return
            }

            do {
                var episodes = try JSONDecoder().decode([Episode].self, from: data)

                // Assign the show title to each episode
                episodes = episodes.map { episode in
                    var updatedEpisode = episode
                    updatedEpisode.showTitle = show.title
                    return updatedEpisode
                }

                DispatchQueue.main.async {
                    completion(episodes)
                }
            } catch {
                print("Failed to decode episodes: \(error.localizedDescription)")
                completion([])
            }
        }.resume()
    }


    func checkForUpcomingEpisodes() {
        guard let serverURL = serverURL, let apiKey = apiKey else {
            print("Server URL or API Key is missing")
            return
        }

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
        guard let serverURL = serverURL, let apiKey = apiKey else {
            print("Server URL or API Key is missing")
            return
        }

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
        guard let serverURL = serverURL, let apiKey = apiKey else {
            print("Server URL or API Key is missing")
            return
        }

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
        guard let serverURL = serverURL, let apiKey = apiKey else { return }
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
        guard let serverURL = publicServerURL, let apiKey = publicApiKey else {
            print("Server URL or API Key is missing")
            return
        }

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
}
