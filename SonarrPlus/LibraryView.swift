import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var viewModel: SonarrPlusViewModel
    @State private var sortAlphabetically: Bool = false
    @State private var showOnlyMonitored: Bool = false

    var sortedAndFilteredShows: [Show] {
        var shows = viewModel.shows

        if sortAlphabetically {
            shows.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        if showOnlyMonitored {
            shows = shows.filter { $0.monitored }
        }

        return shows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Heading
            Text("Currently in Sonarr")
                .font(.title2)
                .bold()
                .padding(.horizontal)
                .padding(.top, 8)

            // Toolbar with Sort and Filter
            HStack {
                Button(action: {
                    sortAlphabetically.toggle()
                }) {
                    Label("Sort A-Z", systemImage: sortAlphabetically ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                        .font(.subheadline)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("Monitored Only")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Toggle("", isOn: $showOnlyMonitored)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8) // Reduce vertical spacing for compactness

            // Show List
            List(sortedAndFilteredShows) { show in
                VStack(alignment: .leading) {
                    Text(show.title)
                        .font(.headline)

                    HStack {
                        Text("Status: \(show.status.capitalized)")
                        Spacer()
                        Text(show.monitored ? "Monitored" : "Not Monitored")
                            .foregroundColor(show.monitored ? .green : .red)
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 5)
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationTitle("Library")
        .onAppear {
            viewModel.fetchLibrary()
        }
    }
}
