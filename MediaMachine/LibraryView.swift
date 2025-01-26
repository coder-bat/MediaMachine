import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var viewModel: MediaMachineViewModel
    @State private var sortAlphabetically: Bool = false
    @State private var showOnlyMonitored: Bool = false

    var sortedAndFilteredShows: [Show] {
        var shows = viewModel.shows

        if sortAlphabetically {
            shows.sort { ($0.title ?? $0.name).localizedCaseInsensitiveCompare($1.title ?? $1.name) == .orderedAscending }
        }

        if showOnlyMonitored {
            shows = shows.filter { $0.monitored ?? false }
        }

        return shows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            .padding(.vertical, 8)

            if viewModel.shows.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Text("Loading library...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ShowListView(currentShows: sortedAndFilteredShows)
                    .environment(\.disableInfiniteScroll, true)
            }
        }
        .navigationTitle("Library")
        .onAppear {
            viewModel.fetchLibrary()
        }
    }
}

// Add environment key to control infinite scroll
private struct DisableInfiniteScrollKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var disableInfiniteScroll: Bool {
        get { self[DisableInfiniteScrollKey.self] }
        set { self[DisableInfiniteScrollKey.self] = newValue }
    }
}
