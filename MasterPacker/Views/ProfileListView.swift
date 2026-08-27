import SwiftUI
import SwiftData

/// Entry point for saved traveler profiles — presented as a sheet from
/// `TripListView`.
struct ProfileListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TravelerProfile.name) private var profiles: [TravelerProfile]
    @State private var isPresentingAddProfile = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if profiles.isEmpty {
                    ContentUnavailableView(
                        "No saved travelers",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Save a traveler's always-pack list once, then reuse it on any trip.")
                    )
                } else {
                    List {
                        ForEach(profiles) { profile in
                            NavigationLink(value: profile) {
                                ProfileRow(profile: profile)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                        .onDelete(perform: deleteProfiles)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Saved Travelers")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: TravelerProfile.self) { profile in
                ProfileDetailView(profile: profile)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddProfile = true
                    } label: {
                        Label("Add Traveler Profile", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddProfile) {
                // Go straight to the new profile's item list once it's
                // created, instead of dropping back to this list.
                NewProfileView { profile in
                    path.append(profile)
                }
            }
        }
    }

    private func deleteProfiles(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(profiles[index])
        }
    }
}

private struct ProfileRow: View {
    let profile: TravelerProfile

    var body: some View {
        HStack(spacing: 13) {
            IconBadge(systemImage: profile.ageBracket.symbol)

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .font(.system(.headline, design: .rounded))
                Text(profile.ageBracket.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(profile.alwaysItems.count) always-pack item\(profile.alwaysItems.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.85))
            }

            Spacer()
        }
        .padding(14)
        .floatingCard()
    }
}

#Preview {
    ProfileListView()
        .modelContainer(
            for: [TravelerProfile.self, ProfileItem.self, CustomCategory.self, Trip.self, Traveler.self, Pet.self, PackingItem.self],
            inMemory: true
        )
}
