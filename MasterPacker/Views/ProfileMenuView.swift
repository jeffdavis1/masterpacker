import SwiftUI

/// The "More" tab in RootTabView (labeled "Profile" until the tab names
/// got trimmed down) — a menu of secondary features that don't need
/// their own top-level tab: archived trips, managing the custom
/// categories/activities users create elsewhere in the app, and the
/// trip map.
///
/// Settings and Logout aren't listed here yet, even though the original
/// nav-redesign spec called for them — neither has anything real behind
/// it today. There's no login system to log out of (the app is just tied
/// to whichever iCloud account is signed in), and account settings is
/// its own separate, not-yet-built roadmap item. Both can join this menu
/// once there's substance behind them instead of shipping dead rows.
struct ProfileMenuView: View {
    @State private var isPresentingArchived = false
    @State private var isPresentingCategories = false
    @State private var isPresentingActivities = false
    @State private var isPresentingMap = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    isPresentingArchived = true
                } label: {
                    Label("Archived", systemImage: "archivebox")
                }
                .listRowBackground(AppTheme.cardSurface)

                Button {
                    isPresentingCategories = true
                } label: {
                    Label("Manage Categories", systemImage: "tag")
                }
                .listRowBackground(AppTheme.cardSurface)

                Button {
                    isPresentingActivities = true
                } label: {
                    Label("Manage Activities", systemImage: "star")
                }
                .listRowBackground(AppTheme.cardSurface)

                Button {
                    isPresentingMap = true
                } label: {
                    Label("Trip Map", systemImage: "map")
                }
                .listRowBackground(AppTheme.cardSurface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("More")
        }
        .sheet(isPresented: $isPresentingArchived) {
            ArchivedTripsView()
        }
        .sheet(isPresented: $isPresentingCategories) {
            CategoryListView()
        }
        .sheet(isPresented: $isPresentingActivities) {
            ActivityListView()
        }
        .sheet(isPresented: $isPresentingMap) {
            TripMapView()
        }
    }
}

#Preview {
    ProfileMenuView()
        .modelContainer(
            for: [
                Trip.self, PackingItem.self, Luggage.self, Traveler.self, Pet.self,
                TravelerProfile.self, PetProfile.self, ProfileItem.self, CustomCategory.self,
                CustomActivity.self, PackingTemplate.self, TemplateItem.self,
            ],
            inMemory: true
        )
}
