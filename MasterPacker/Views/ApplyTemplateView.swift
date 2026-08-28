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
                        description: Text("Save a reusable packing list from My Bag first.")
                    )
                } else {
                    List {
                        ForEach(templates) { template in
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
            .navigationTitle("Add from My Bag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func apply(_ template: PackingTemplate) {
        for templateItem in template.items {
            let item = PackingItem(
                name: templateItem.name,
                category: templateItem.category,
                quantity: templateItem.quantity,
                trip: trip
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
        .modelContainer(for: [Trip.self, PackingItem.self, PackingTemplate.self, TemplateItem.self], inMemory: true)
}
