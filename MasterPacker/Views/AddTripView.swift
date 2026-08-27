import SwiftUI
import SwiftData

struct AddTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60 * 60 * 24 * 3)
    @State private var tripType: TripType = .general
    @State private var generateSuggestions = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    TextField("Trip name", text: $name)
                    TextField("Destination", text: $destination)
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                Section("Type") {
                    Picker("Trip type", selection: $tripType) {
                        ForEach(TripType.allCases) { type in
                            Label(type.rawValue, systemImage: type.symbol).tag(type)
                        }
                    }
                }
                Section {
                    Toggle("Generate suggested packing list", isOn: $generateSuggestions)
                } footer: {
                    Text("Adds a starter checklist based on trip type and length. You can edit it afterward.")
                }
            }
            .navigationTitle("New Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trip = Trip(name: name, destination: destination, startDate: startDate, endDate: endDate, tripType: tripType)
        modelContext.insert(trip)

        if generateSuggestions {
            let suggestions = PackingTemplate.suggestedItems(for: tripType, days: trip.durationInDays)
            for suggestion in suggestions {
                let item = PackingItem(name: suggestion.name, category: suggestion.category, quantity: suggestion.quantity, trip: trip)
                modelContext.insert(item)
            }
        }

        dismiss()
    }
}

#Preview {
    AddTripView()
        .modelContainer(for: [Trip.self, PackingItem.self], inMemory: true)
}
