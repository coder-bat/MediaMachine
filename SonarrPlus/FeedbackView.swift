//
//  FeedbackView.swift
//  SonarrPlus
//
//  Created by Coder Bat on 16/1/2025.
//


import SwiftUI
import MessageUI

struct FeedbackView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposeVC = MFMailComposeViewController()
        mailComposeVC.setToRecipients(["harekrsna.vira@gmail.com"])
        mailComposeVC.setSubject("SonarrPlus Feedback")
        mailComposeVC.setMessageBody("Hi, I'd like to share the following feedback about SonarrPlus:\n\n", isHTML: false)
        mailComposeVC.mailComposeDelegate = context.coordinator
        return mailComposeVC
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: FeedbackView

        init(_ parent: FeedbackView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.isPresented = false
        }
    }
}
