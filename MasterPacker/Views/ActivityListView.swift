import SwiftUI
import SwiftData

/// Manage (rename or delete) custom trip activities — the ones users
/// create on the fly via "Custom" while picking activities on the
/// New/Edit Trip form. Built-in activities (`Activity`'s fixed cases)
/// aren't listed here; there's nothing to manage about them.
struct ActivityListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomActivity.name) private var customActivities: [CustomActivity]

    @State private var renamingActivity: CustomActivity?
    @State private var renameText = ""
    @State private var deletingActivity: CustomActivity?
    @State private var isAddingActivity = false
    @State private var newActivityName = ""

    var body: some View {
        NavigationStack {
            Group {
                if customActivities.isEmpty {
                    ContentUnavailableView {
                        Label("No custom activities yet", systemImage: "star")
                    } description: {
                        Text("Activities you create while picking a trip's activities show up here, or add one directly below.")
                    } actions: {
                        Button("Add Activity") { isAddingActivity = true }
                    }
                } else {
                    List {
                        ForEach(customActivities) { activity in
                            Button {
                                beginRename(activity)
                            } label: {
                                HStack {
                                    Text(activity.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .listRowBackground(AppTheme.cardSurface)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deletingActivity = activity
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Manage Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingActivity = true
                    } label: {
                        Label("Add Activity", systemImage: "plus")
                    }
                }
            }
            .alert("New Activity", isPresented: $isAddingActivity) {
                TextField("Activity name", text: $newActivityName)
                Button("Cancel", role: .cancel) { newActivityName = "" }
                Button("Add") { addActivity() }
            } message: {
                Text("Shows up as an activity chip the next time you're planning a trip.")
            }
            .alert("Rename Activity", isPresented: renameAlertBinding) {
                TextField("Activity name", text: $renameText)
                Button("Cancel", role: .cancel) { renamingActivity = nil }
                Button("Save") { commitRename() }
            } message: {
                Text("Trips already using this activity move to the new name too.")
            }
            .alert(
                "Delete “\(deletingActivity?.name ?? "")”?",
                isPresented: deleteAlertBinding
            ) {
                Button("Cancel", role: .cancel) { deletingActivity = nil }
                Button("Delete", role: .destructive) { commitDelete() }
            } message: {
                Text("Trips already using this activity will no longer show it.")
            }
        }
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renamingActivity != nil },
            set: { isPresented in if !isPresented { renamingActivity = nil } }
        )
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingActivity != nil },
            set: { isPresented in if !isPresented { deletingActivity = nil } }
        )
    }

    /// Same collision rule as the inline "Custom" chip on ActivityChipGrid
    /// — case-insensitive against both built-in activities and existing
    /// custom ones. A collision here just quietly does nothing (there's
    /// no trip being edited to fall back to selecting on, unlike there).
    private func addActivity() {
        let trimmed = newActivityName.trimmingCharacters(in: .whitespaces)
        newActivityName = ""
        guard !trimmed.isEmpty else { return }

        let existingNames = Set(
            Activity.allCases.map { $0.rawValue.lowercased() } + customActivities.map { $0.name.lowercased() }
        )
        guard !existingNames.contains(trimmed.lowercased()) else { return }

        modelContext.insert(CustomActivity(name: trimmed))
        AnalyticsService.customActivityCreated()
    }

    private func beginRename(_ activity: CustomActivity) {
        renameText = activity.name
        renamingActivity = activity
    }

    private func commitRename() {
        guard let activity = renamingActivity else { return }
        renamingActivity = nil
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != activity.name else { return }

        // Same case-insensitive collision check "Custom" itself uses —
        // don't let a rename collide with a built-in activity or a
        // different custom one.
        let existingNames = Set(
            Activity.allCases.map { $0.rawValue.lowercased() } +
            customActivities.filter { $0.id != activity.id }.map { $0.name.lowercased() }
        )
        guard !existingNames.contains(trimmed.lowercased()) else { return }

        let oldName = activity.name
        activity.name = trimmed
        reassignActivityUsages(from: oldName, to: trimmed)
    }

    private func commitDelete() {
        guard let activity = deletingActivity else { return }
        deletingActivity = nil
        reassignActivityUsages(from: activity.name, to: nil)
        modelContext.delete(activity)
    }

    /// Sweeps every trip's activity selection and either renames or
    /// drops (when `newName` is nil) any use of `oldName` — unlike a
    /// custom packing category, a trip doesn't need a fallback activity
    /// to land on when one is deleted; simply no longer having it
    /// selected is a perfectly normal state.
    private func reassignActivityUsages(from oldName: String, to newName: String?) {
        guard let trips = try? modelContext.fetch(FetchDescriptor<Trip>()) else { return }
        for trip in trips where trip.activityRawValues.contains(oldName) {
            var names = trip.activityNames
            names.remove(oldName)
            if let newName {
                names.insert(newName)
            }
            trip.activityNames = names
        }
    }
}

#Preview {
    ActivityListView()
        .modelContainer(
            for: [CustomActivity.self, Trip.self, PackingItem.self, Luggage.self, Traveler.self, Pet.self],
            inMemory: true
        )
}
