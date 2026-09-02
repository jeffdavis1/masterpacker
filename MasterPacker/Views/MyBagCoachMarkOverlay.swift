import SwiftUI

/// One-time onboarding nudge toward the My Bag tab — see CoachMarkStore
/// for exactly when it shows/hides. Lives inside RootTabView, layered
/// over the TabView, since it needs `selectedTab` to switch to My Bag
/// when tapped and needs the tab bar to actually be on screen to point
/// at.
struct MyBagCoachMarkOverlay: View {
    @Binding var selectedTab: RootTabView.Tab
    @State private var isVisible = CoachMarkStore.shouldShowMyBagCoachMark

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
    }

    private var coachMark: some View {
        VStack(spacing: 0) {
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
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(AppTheme.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .contentShape(Rectangle())
            .onTapGesture {
                navigateToMyBag()
            }

            // My Bag is the middle tab of five, so a centered pointer
            // lines up with it without needing per-device tab-bar
            // geometry.
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.brand)
                .offset(y: -1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 74)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeOut(duration: 0.3), value: isVisible)
    }

    private func navigateToMyBag() {
        selectedTab = .myBag
        // The onChange handler above also catches this, but setting it
        // here too means the bubble disappears immediately on tap
        // instead of waiting a beat for the tab-change callback.
        isVisible = false
    }

    private func dismiss() {
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
