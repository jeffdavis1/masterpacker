import SwiftUI

/// The app's top-level navigation shell — five tabs covering the core
/// trip-packing workflow (My Trips, Shared With Me, My Bag, Saved
/// Travelers) plus a Profile tab for secondary, less-frequent features.
/// Replaces the old single-screen-plus-"More"-menu structure, which
/// buried quick-access features like My Bag and Saved Travelers a menu
/// tap deeper than a first-time user should have to dig.
///
/// Each tab's root view (TripListView, SharedTripsListView,
/// TemplateListView, ProfileListView) already owns its own NavigationStack
/// and used to also carry a "Close" button back when it was presented as
/// a sheet from TripListView's More menu — that's gone now that each is
/// a tab in its own right instead of something you dismiss.
///
/// selectedTab is exposed (not just `@State private`) so
/// MyBagCoachMarkOverlay can switch to the My Bag tab when its coach mark
/// is tapped.
struct RootTabView: View {
    @State var selectedTab: Tab = .myTrips

    enum Tab: Hashable {
        case myTrips, shared, myBag, travelers, profile
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                TripListView()
                    .tabItem {
                        Label("My Trips", systemImage: "suitcase.fill")
                    }
                    .tag(Tab.myTrips)
                SharedTripsListView()
                    .tabItem {
                        Label("Shared With Me", systemImage: "person.2.fill")
                    }
                    .tag(Tab.shared)
                TemplateListView()
                    .tabItem {
                        Label("My Bag", systemImage: "bag.fill")
                    }
                    .tag(Tab.myBag)
                ProfileListView()
                    .tabItem {
                        Label("Saved Travelers", systemImage: "person.crop.circle")
                    }
                    .tag(Tab.travelers)
                ProfileMenuView()
                    .tabItem {
                        Label("Profile", systemImage: "person.circle.fill")
                    }
                    .tag(Tab.profile)
            }

            MyBagCoachMarkOverlay(selectedTab: $selectedTab)
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(
            for: [
                Trip.self, PackingItem.self, Luggage.self, Traveler.self, Pet.self,
                TravelerProfile.self, PetProfile.self, ProfileItem.self, CustomCategory.self,
                CustomActivity.self, PackingTemplate.self, TemplateItem.self,
            ],
            inMemory: true
        )
}
