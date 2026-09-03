import SwiftUI
import SwiftData

/// Entry point for saved traveler and pet profiles — the "Saved
/// Travelers" tab in RootTabView.
struct ProfileListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TravelerProfile.name) private var travelerProfiles: [TravelerProfile]
    @Query(sort: \PetProfile.name) private var petProfiles: [PetProfile]
    @State private var isPresentingAddProfile = false
    @State private var isPresentingAddPetProfile = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if travelerProfiles.isEmpty && petProfiles.isEmpty {
                    ContentUnavailableView(
                        "No saved travelers or pets",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Save someone's essentials once, then reuse it on any trip.")
                    )
                } else {
                    List {
                        if !travelerProfiles.isEmpty {
                            Section("Travelers") {
                                ForEach(travelerProfiles) { profile in
                                    NavigationLink(value: profile) {
                                        ProfileRow(
                                            name: profile.name,
                                            subtitle: profile.ageBracket.rawValue,
                                            symbol: profile.ageBracket.symbol,
                                            itemCount: profile.alwaysItems.count
                                        )
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                }
                                .onDelete(perform: deleteTravelerProfiles)
                            }
                        }

                        if !petProfiles.isEmpty {
                            Section("Pets") {
                                ForEach(petProfiles) { profile in
                                    NavigationLink(value: profile) {
                                        ProfileRow(
                                            name: profile.name,
                                            subtitle: profile.species.rawValue,
                                            symbol: profile.species.symbol,
                                            itemCount: profile.alwaysItems.count
                                        )
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                }
                                .onDelete(perform: deletePetProfiles)
                            }
                        }
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
            .navigationDestination(for: PetProfile.self) { profile in
                PetProfileDetailView(profile: profile)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            isPresentingAddProfile = true
                        } label: {
                            Label("Add Traveler", systemImage: "person.crop.circle")
                        }
                        Button {
                            isPresentingAddPetProfile = true
                        } label: {
                            Label("Add Pet", systemImage: "pawprint")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
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
            .sheet(isPresented: $isPresentingAddPetProfile) {
                NewPetProfileView { profile in
                    path.append(profile)
                }
            }
        }
    }

    private func deleteTravelerProfiles(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(travelerProfiles[index])
        }
    }

    private func deletePetProfiles(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(petProfiles[index])
        }
    }
}

private struct ProfileRow: View {
    let name: String
    let subtitle: String
    let symbol: String
    let itemCount: Int

    var body: some View {
        HStack(spacing: 13) {
            IconBadge(systemImage: symbol)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(.headline, design: .rounded))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(itemCount) Essential\(itemCount == 1 ? "" : "s")")
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
            for: [
                TravelerProfile.self, PetProfile.self, ProfileItem.self, CustomCategory.self,
                Trip.self, Traveler.self, Pet.self, PackingItem.self, Luggage.self,
            ],
            inMemory: true
        )
}
