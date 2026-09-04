import SwiftData
import SwiftUI
import UIKit

/// One-time onboarding nudge toward the My Bag tab — see CoachMarkStore
/// for exactly when it shows/hides. Lives inside RootTabView, layered
/// over the TabView, since it needs `selectedTab` to switch to My Bag
/// when tapped and needs the tab bar to actually be on screen to point
/// at.
struct MyBagCoachMarkOverlay: View {
    @Binding var selectedTab: RootTabView.Tab
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isVisible = CoachMarkStore.shouldShowMyBagCoachMark

    // CoachMarkStore's "first bag created" flag lives in UserDefaults,
    // which is local to this install — it resets on reinstall even
    // though the bags themselves come right back via CloudKit sync. Left
    // unguarded, that means a returning user with existing bags sees
    // "create your first bag" again. This @Query is the live check
    // against that: whenever real bags actually exist, on this launch or
    // whenever CloudKit sync catches up shortly after, retire the coach
    // mark the same permanent way creating one normally would.
    @Query private var templates: [PackingTemplate]

    /// True only when the tab bar is actually rendered at the TOP of the
    /// screen — iPadOS's own adaptive behavior for a plain TabView once
    /// the window is wide enough. Checking horizontalSizeClass alone
    /// isn't enough: big iPhones (Plus/Max) also report `.regular` in
    /// landscape, but their tab bar never leaves the bottom — the top
    /// tab bar is an iPad-only windowing behavior. Requiring both means
    /// this can never trigger on an iPhone, in any orientation, and
    /// still correctly falls back to bottom-pointing on an iPad in a
    /// narrow Split View/Slide Over, where the tab bar drops back down
    /// to match iPhone.
    private var tabBarIsOnTop: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {
        // Wrapped in Group so onChange below stays attached even once
        // isVisible is false and the if-branch renders nothing.
        Group {
            if isVisible {
                coachMark
            }
        }
        // Reacts to My Bag being selected any way — tapping the coach
        // mark itself (see navigateToMyBag) or tapping the My Bag tab
        // bar item directly — since it wouldn't make sense to keep
        // pointing at a tab the user is already looking at. Not a
        // dismissal either way: only the X counts against the limit, so
        // if they leave without creating a bag it's still due to show
        // again next launch.
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .myBag {
                isVisible = false
            }
        }
        // Covers reinstall: bags synced back from CloudKit are usually
        // already present by the time this view first appears. Also
        // reacts to the count changing afterward, since that sync can
        // still be in flight at launch and finish a moment later.
        // Either way, retire the coach mark the same permanent way a
        // bag created on this install would — not just for this launch.
        .onAppear { retireIfBagsExist() }
        .onChange(of: templates.count) { _, _ in retireIfBagsExist() }
    }

    private func retireIfBagsExist() {
        guard !templates.isEmpty else { return }
        isVisible = false
        CoachMarkStore.recordFirstBagCreated()
    }

    private var coachMark: some View {
        VStack(spacing: 0) {
            if tabBarIsOnTop {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.brand)
                    .offset(y: 1)
            }

            HStack(alignment: .top, spacing: 10) {
                Text("Start here — Create a bag with items you always need and easily add it to any trip")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // A dedicated dismiss target — separate from the tap-
                // to-navigate gesture on the rest of the bubble below,
                // same "one thing confirms, one thing declines"
                // split used for delete confirmations elsewhere.
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .accessibilityLabel("Dismiss")
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(AppTheme.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .contentShape(Rectangle())
            .onTapGesture {
                navigateToMyBag()
            }

            if !tabBarIsOnTop {
                // My Bag is the middle tab of five, so a centered pointer
                // lines up with it without needing per-device tab-bar
                // geometry.
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.brand)
                    .offset(y: -1)
            }
        }
        .padding(.horizontal, 24)
        // The exact clearance a top tab bar needs is a guess without a
        // device to check it against (60pt — status bar plus iPadOS's
        // floating tab bar) — same "verify by eye, adjust if it's off"
        // as everything else in this feature. The bottom value (74) is
        // unchanged and was already tuned against a real device.
        .padding(tabBarIsOnTop ? .top : .bottom, tabBarIsOnTop ? 60 : 74)
        // Fills the overlay's full space itself and aligns within that,
        // rather than relying on RootTabView's ZStack alignment (fixed
        // to .bottom, for the iPhone case) — lets this flip to the top
        // on iPad without needing a matching change over there.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: tabBarIsOnTop ? .top : .bottom)
        .transition(.opacity.combined(with: .move(edge: tabBarIsOnTop ? .top : .bottom)))
        .animation(.easeOut(duration: 0.3), value: isVisible)
        .onAppear {
            AnalyticsService.myBagCoachMarkShown()
        }
    }

    private func navigateToMyBag() {
        AnalyticsService.myBagCoachMarkTapped()
        selectedTab = .myBag
        // The onChange handler above also catches this, but setting it
        // here too means the bubble disappears immediately on tap
        // instead of waiting a beat for the tab-change callback.
        isVisible = false
    }

    private func dismiss() {
        AnalyticsService.myBagCoachMarkDismissed()
        CoachMarkStore.recordMyBagCoachMarkDismissal()
        isVisible = false
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
