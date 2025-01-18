import SwiftUI

struct WalkthroughView: View {
    @State private var currentTab = 0
    private let walkthroughImages = ["walkthrough1", "walkthrough2", "walkthrough3", "walkthrough4"] // Add your image names here
    @AppStorage("hasSeenWalkthrough") private var hasSeenWalkthrough = false

    var body: some View {
        VStack {
            TabView(selection: $currentTab) {
                ForEach(0..<walkthroughImages.count, id: \.self) { index in
                    SwiftUI.Image(walkthroughImages[index])
                        .resizable()
                        .scaledToFit()
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .frame(height: .infinity)
            if currentTab == walkthroughImages.count - 1 {
                Button(action: {
                    navigateToSonarrConnectionScreen()
                }) {
                    Text(currentTab == walkthroughImages.count - 1 ? "Let’s Go" : "Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private func navigateToSonarrConnectionScreen() {
        // Add your navigation logic to the Sonarr connection screen here
        print("Navigate to Sonarr connection screen")
        hasSeenWalkthrough = true
    }
}

struct WalkthroughView_Previews: PreviewProvider {
    static var previews: some View {
        WalkthroughView()
    }
}
