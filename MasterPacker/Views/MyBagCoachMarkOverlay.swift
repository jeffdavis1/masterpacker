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
        if isVisible {
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
    }

    private func navigateToMyBag() {
        selectedTab = .myBag
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
