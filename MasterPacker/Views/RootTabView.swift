import SwiftUI

/// The app's top-level navigation shell — five tabs covering the core
/// trip-packing workflow (My Trips, Shared, My Bag, Travelers) plus a
/// More tab for secondary, less-frequent features. Replaces the old
/// single-screen-plus-"More"-menu structure, which buried quick-access
/// features like My Bag and Saved Travelers a menu tap deeper than a
/// first-time user should have to dig.
///
/// Tab labels were trimmed from their original longer form ("Shared
/// With Me" → "Shared", "Saved Travelers" → "Travelers", "Profile" →
/// "More") once the actual 5-item bar shipped and read as cramped.
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
                        // person.2.fill (people, no context of "shared
                        // between devices/apps") moved to Travelers below,
                        // where it fits just as well — this tab gets its
                        // own distinct icon instead of reusing it.
                        Label("Shared", systemImage: "person.line.dotted.person.fill")
                    }
                    .tag(Tab.shared)
                TemplateListView()
                    .tabItem {
                        Label("My Bag", systemImage: "bag.fill")
                    }
                    .tag(Tab.myBag)
                ProfileListView()
                    .tabItem {
                        Label("Travelers", systemImage: "person.2.fill")
                    }
                    .tag(Tab.travelers)
                ProfileMenuView()
                    .tabItem {
                        // Back to the exact icon the old "More" toolbar
                        // menu used, since this tab replaced it and is
                        // now labeled the same way.
                        Label("More", systemImage: "ellipsis.circle")
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
