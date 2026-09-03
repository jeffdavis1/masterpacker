import SwiftUI
import SwiftData

/// Lets the user pick a saved template to apply to a trip — tapping one
/// immediately adds its items to the trip's shared/household bucket and
/// dismisses. An immediate action, not a multi-select + Save flow, since
/// applying a template is a one-shot "add these now".
struct ApplyTemplateView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PackingTemplate.name) private var templates: [PackingTemplate]

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView(
                        "No bags yet",
                        systemImage: "bag",
                        description: Text("Save a reusable packing list from My Bags first.")
                    )
                } else if availableTemplates.isEmpty {
                    // Distinct from the "no bags at all" case above —
                    // bags exist, they're just all assigned to travelers
                    // who aren't on this trip.
                    ContentUnavailableView(
                        "No bags for this trip's travelers",
                        systemImage: "bag",
                        description: Text("Your saved bags are each assigned to a traveler who isn't on this trip. Unassign a bag's owner in My Bags to make it available everywhere again.")
                    )
                } else {
                    List {
                        ForEach(availableTemplates) { template in
                            Button {
                                apply(template)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                            .foregroundStyle(.primary)
                                        Text("\(template.items.count) item\(template.items.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .listRowBackground(AppTheme.cardSurface)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Add from My Bags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    /// Bags offered here — an unowned bag is available for any trip; an
    /// owned one only shows up when its owner is one of this trip's
    /// actual travelers. A trip's Traveler has no stored link back to the
    /// TravelerProfile it was created from, so matching by name is the
    /// same proxy ProfileDetailView's frequent-item suggestions already
    /// use for the same reason.
    private var availableTemplates: [PackingTemplate] {
        templates.filter { template in
            guard let owner = template.owner else { return true }
            return trip.travelers.contains { $0.name == owner.name }
        }
    }

    private func apply(_ template: PackingTemplate) {
        // An owned bag's items are that specific traveler's kit, not
        // household gear — assign them to the matching Traveler on this
        // trip, not the shared bucket. Only an unowned bag still lands
        // as shared.
        let owningTraveler = template.owner.flatMap { owner in
            trip.travelers.first { $0.name == owner.name }
        }
        for templateItem in template.items {
            let item = PackingItem(
                name: templateItem.name,
                categoryName: templateItem.categoryName,
                quantity: templateItem.quantity,
                trip: trip,
                traveler: owningTraveler
            )
            modelContext.insert(item)
        }
        AnalyticsService.bagAppliedToTrip()
        Task { await TripSharingService.shared.resyncIfShared(trip) }
        dismiss()
    }
}

#Preview {
    let trip = Trip(name: "Preview", destination: "Somewhere", startDate: .now, endDate: .now)
    return ApplyTemplateView(trip: trip)
        .modelContainer(
            for: [
                Trip.self, PackingItem.self, Luggage.self, PackingTemplate.self, TemplateItem.self,
                TravelerProfile.self, ProfileItem.self,
            ],
            inMemory: true
        )
}
