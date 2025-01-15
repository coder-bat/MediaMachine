import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var viewModel = SonarrPlusViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enable or disable notifications for your shows below. Notifications will alert you about upcoming episodes.")
                .font(.body)
                .padding()

            List {
                ForEach($viewModel.shows) { $show in
                    Toggle(isOn: Binding(
                        get: { show.notificationsEnabled ?? false },
                        set: { newValue in
                            show.notificationsEnabled = newValue
                        }
                    )) {
                    Text(show.title)
                    }
                    .onChange(of: show.notificationsEnabled) {
                        viewModel.saveNotificationPreferences()
                    }
                }
            }
        }
        .navigationTitle("Notification Settings")
    }
}
