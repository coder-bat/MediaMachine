import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: SonarrPlusViewModel
    @State private var serverURL = ""
    @State private var apiKey = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Connect to Sonarr")
                .font(.largeTitle)
                .padding()

            TextField("Server URL", text: $serverURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            SecureField("API Key", text: $apiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

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
        }
        .padding()
        .edgesIgnoringSafeArea(.all)
    }
}
