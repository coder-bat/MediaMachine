import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var searchResults: [Show] = []
    @EnvironmentObject var viewModel: MediaMachineViewModel

    var body: some View {
        NavigationView {
            VStack {
                TextField("Search for shows...", text: $query, onCommit: {
                    searchShows()
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

                List(searchResults) { show in
                    VStack(alignment: .leading) {
                        Text(show.title ?? "Undefined Title")
                            .font(.headline)
                        if let overview = show.overview {
                            Text(overview)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                    }
                    .onTapGesture {
                        addShow(show)
                    }
                }
            }
            .navigationTitle("Search Shows")
        }
    }

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

            guard let data = data else { return }

            do {
                let shows = try JSONDecoder().decode([Show].self, from: data)
                DispatchQueue.main.async {
                    self.searchResults = shows
                }
            } catch {
                print("Failed to decode search results: \(error.localizedDescription)")
            }
        }.resume()
    }

    private func addShow(_ show: Show) {
        guard let serverURL = viewModel.publicServerURL, let _ = viewModel.publicApiKey else {
            print("Server URL or API Key is missing")
            return
        }

        guard let rootFolderPath = viewModel.rootFolderPath else {
            print("Root folder path is not available")
            return
        }

        let urlString = "\(serverURL)/api/v3/series"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            var showToAdd = show
            showToAdd.path = "\(rootFolderPath)/\(show.cleanTitle ?? "Unknown Title")"
            showToAdd.qualityProfileId = 1 // Example profile ID
            showToAdd.monitored = true

            let bodyData = try JSONEncoder().encode(showToAdd)
            request.httpBody = bodyData

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Failed to add show: \(error.localizedDescription)")
                    return
                }

                print("Show added successfully!")
            }.resume()
        } catch {
            print("Failed to encode show: \(error.localizedDescription)")
        }
    }
}
