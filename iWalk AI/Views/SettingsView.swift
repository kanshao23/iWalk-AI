import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Support") {
                    Button {
                        openFeedbackMail()
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                            .foregroundStyle(Color.iwOnSurface)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func openFeedbackMail() {
        let address = "support@kanverse.app"
        let subject = "iWalk AI Feedback"
        let body = ""
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }
}
