//
//  QualityPicker.swift
//  MediaMachine
//
//  Created by Coder Bat on 14/1/2025.
//

import SwiftUI

struct QualityPicker: View {
    let profiles: [QualityProfile]
    let completion: (QualityProfile, Bool) -> Void
    @Environment(\.presentationMode) private var presentationMode

    @State private var selectedProfile: QualityProfile?
    @State private var startDownload: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Select Quality Profile")
                .font(.headline)

            Picker("Quality Profile", selection: $selectedProfile) {
                ForEach(profiles, id: \.id) { profile in
                    Text(profile.name).tag(profile as QualityProfile?)
                }
            }
            .pickerStyle(WheelPickerStyle())

            Toggle("Start Download Immediately", isOn: $startDownload)
                .padding()

            Button(action: {
                if let selectedProfile = selectedProfile {
                    completion(selectedProfile, startDownload)
                    presentationMode.wrappedValue.dismiss() // Close the popup
                }
            }) {
                Text("Confirm")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedProfile == nil) // Disable if no profile is selected
        }
        .padding()
    }
}


// Model for Quality Profile
struct QualityProfile: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}
