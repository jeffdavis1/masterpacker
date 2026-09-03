import SwiftUI

/// Feedback form reachable from the More tab. See FeedbackService for
/// where this actually goes (CloudKit's public database) and why that's
/// not quite the same thing as "anonymous."
struct SendFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var submitErrorMessage: String?
    @State private var didSubmit = false

    private var isValid: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 160)
                } header: {
                    Text("Your feedback")
                } footer: {
                    Text("No name, email, or account info is attached — just your message.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Send") { submit() }
                            .disabled(!isValid)
                    }
                }
            }
            // Message deliberately isn't cleared here — a failed
            // submission (offline, etc.) shouldn't cost the user their
            // typed feedback; Send stays tappable to retry.
            .alert(
                "Couldn't Send Feedback",
                isPresented: Binding(
                    get: { submitErrorMessage != nil },
                    set: { isPresented in if !isPresented { submitErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(submitErrorMessage ?? "Please check your connection and try again.")
            }
            .alert("Thanks!", isPresented: $didSubmit) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your feedback has been sent.")
            }
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            do {
                try await FeedbackService.submit(message: message)
                AnalyticsService.feedbackSubmitted()
                isSubmitting = false
                didSubmit = true
            } catch {
                isSubmitting = false
                submitErrorMessage = "Please check your connection and try again."
            }
        }
    }
}

#Preview {
    SendFeedbackView()
}
