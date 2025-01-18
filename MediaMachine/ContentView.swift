import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: MediaMachineViewModel
    @AppStorage(AppStorageKeys.serverURL) private var serverURL = ""
    @AppStorage(AppStorageKeys.apiKey) private var apiKey = ""
    @State private var errorMessage: String?

    private func attemptAutoConnect() {
        // Only try to connect if we have stored values
        if !serverURL.isEmpty && !apiKey.isEmpty {
            print("serverURL", serverURL);
            viewModel.authenticateWithApiKey(serverURL: serverURL, apiKey: apiKey) { success, error in
                if !success {
                    errorMessage = error
                } else {
                    print("Attempting to save Server URL and API Key...")
                    // set storage serverURL to serverURL
                    UserDefaults.standard.set(serverURL, forKey: AppStorageKeys.serverURL)
                    UserDefaults.standard.set(apiKey, forKey: AppStorageKeys.apiKey)
                    print("Saved Server URL:", UserDefaults.standard.string(forKey: AppStorageKeys.serverURL) ?? "Not saved")
                    print("Saved API Key:", UserDefaults.standard.string(forKey: AppStorageKeys.apiKey) ?? "Not saved")

                    print("Auto-connected successfully!")
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Connect to Sonarr")
                .font(.largeTitle)
                .padding()
                .foregroundColor(.blue)

            Spacer()

            Text("Server IP (Including BaseURL)")
                .font(.title3)
                .padding(0)
                .bold()
            TextField("Server URL", text: $serverURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom)

            Text("Sonarr API Key")
                .font(.title3)
                .padding(0)
                .bold()
            Text("You can get it from Settings -> General in Sonarr")
                .font(.caption)
                .padding(0)
                .bold()
            SecureField("API Key", text: $apiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom)
            Spacer()
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            Button("Connect") {
                viewModel.authenticateWithApiKey(serverURL: serverURL, apiKey: apiKey) { success, error in
                    if !success {
                        errorMessage = error
                    } else {
                        print("Connected successfully!")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            attemptAutoConnect()
        }
    }
}
