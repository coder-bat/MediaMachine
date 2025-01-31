import SwiftUI

struct ActivityManagerView: View {
    @StateObject private var viewModel = MediaMachineViewModel.shared

    var body: some View {
        NavigationView {
            // if no items then print no activity to show
            if viewModel.downloadQueue.isEmpty {
                Text("No activity to show")
            }
            List(viewModel.downloadQueue) { item in
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.title)
                        .font(.headline)

                    Text("Quality: \(item.quality.quality.name) (\(item.quality.quality.resolution)p)")
                        .font(.subheadline)

                    Text("Status: \(item.status)")
                        .font(.subheadline)

                    HStack {
                        Text("Size: \(String(format: "%.2f", item.size / 1_073_741_824)) GB")
                        Spacer()
                        Text("Remaining: \(String(format: "%.2f", item.sizeleft / 1_073_741_824)) GB")
                    }
                    .font(.caption)

                    if item.timeleft != "00:00:00" {
                        Text("Time Left: \(item.timeleft)")
                            .font(.caption)
                    }

                    Text("Completion Time: \(item.estimatedCompletionTime)")
                        .font(.caption)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.cancelDownload(id: item.id)
                        }
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                }
                .padding(.vertical, 5)
            }
            .refreshable {
                Task {
                    await viewModel.fetchDownloadQueue()
                }
            }
            .onAppear {
                Task {
                    await viewModel.fetchDownloadQueue()
                }
            }
        }
    }
}
