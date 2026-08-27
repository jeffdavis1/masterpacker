import SwiftUI

/// Shown briefly on cold launch, before the trip list appears.
struct SplashScreenView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.brand, AppTheme.navy],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "suitcase.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.cream)

                Text("MasterPacker")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Pack smarter, every trip.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.cream.opacity(0.85))
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
