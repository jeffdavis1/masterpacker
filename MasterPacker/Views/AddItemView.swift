import SwiftUI
import SwiftData

struct AddItemView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    @State private var name = ""
    @State private var categoryName = PackingCategory.misc.rawValue
    @State private var quantity = 1
    @State private var assignee: AssigneeOption = .shared
    @State private var isAddingCustomCategory = false
    @State private var newCategoryName = ""
    /// Suggestion chips tapped but not yet saved — same "toggle, don't
    /// insert immediately" pattern as TemplateDetailView/ProfileDetailView
    /// use for their own suggestion pickers, so the grid doesn't reflow
    /// mid-browse. Committed alongside the manual entry below (if any) in
    /// one Save, so someone can pick several curated items AND type one
    /// more custom name in the same visit.
    @State private var pendingSuggestions: Set<CommonProfileItems.Suggestion> = []

    var body: some View {
        NavigationStack {
            Form {
                // Leads with suggestions rather than the manual form —
                // most items someone wants to add already exist in the
                // curated list, and typing a brand-new name every time
                // was the only option before this existed.
                if !curatedSuggestions.isEmpty {
                    Section {
                        ForEach(CommonProfileItems.grouped(curatedSuggestions), id: \.group) { bucket in
                            DisclosureGroup(bucket.group) {
                                SuggestionChipGrid(suggestions: bucket.suggestions, selected: pendingSuggestions, onToggle: togglePending)
                                    .padding(.top, 4)
                            }
                        }
                    } header: {
                        Text("Suggested items")
                    } footer: {
                        Text("Tap any you want, then Save. These go to Everyone — use the form below instead to assign one to a specific traveler or pet.")
                    }
                }

                Section {
                    TextField("Item name", text: $name)
                    Picker("Category", selection: $categoryName) {
                        ForEach(PackingCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.symbol).tag(category.rawValue)
                        }
                        ForEach(customCategories) { custom in
                            Label(custom.name, systemImage: "tag").tag(custom.name)
                        }
                    }
                    Button {
                        isAddingCustomCategory = true
                    } label: {
                        Label("Add custom category", systemImage: "plus")
                    }
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...20)
                    Picker("Assign to", selection: $assignee) {
                        Text("Everyone").tag(AssigneeOption.shared)
                        ForEach(trip.travelers) { traveler in
                            Text(traveler.name).tag(AssigneeOption.traveler(traveler))
                        }
                        ForEach(trip.pets) { pet in
                            Text("\(pet.name) (pet)").tag(AssigneeOption.pet(pet))
                        }
                    }
                } header: {
                    Text("Or add your own")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(pendingSuggestions.isEmpty && name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("New Category", isPresented: $isAddingCustomCategory) {
                TextField("Category name", text: $newCategoryName)
                Button("Cancel", role: .cancel) { newCategoryName = "" }
                Button("Add") { addCustomCategory() }
            } message: {
                Text("Saved categories can be reused for future items.")
            }
        }
    }

    /// Every curated item not already on this trip, under anyone — same
    /// "don't suggest what's already there" filtering TemplateDetailView
    /// and ProfileDetailView both do for their own suggestion lists.
    private var curatedSuggestions: [CommonProfileItems.Suggestion] {
        let existingNames = Set(trip.items.map { $0.name.lowercased() })
        return CommonProfileItems.all.filter { !existingNames.contains($0.name.lowercased()) }
    }

    private func togglePending(_ suggestion: CommonProfileItems.Suggestion) {
        if pendingSuggestions.contains(suggestion) {
            pendingSuggestions.remove(suggestion)
        } else {
            pendingSuggestions.insert(suggestion)
        }
    }

    private func addCustomCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        newCategoryName = ""
        guard !trimmed.isEmpty else { return }

        let existingNames = Set(
            PackingCategory.allCases.map { $0.rawValue.lowercased() } + customCategories.map { $0.name.lowercased() }
        )
        if !existingNames.contains(trimmed.lowercased()) {
            modelContext.insert(CustomCategory(name: trimmed))
            AnalyticsService.customCategoryCreated()
        }
        categoryName = trimmed
    }

    private func save() {
        var didAddAnything = false

        // Suggested items always go to Everyone — same default the
        // manual form itself starts on, and consistent with every other
        // suggestion picker in the app (none of them ask for a
        // traveler/pet per selected chip). Guarded against duplicates
        // the same way AddTripView/EditTripView/ApplyTemplateView are.
        for suggestion in pendingSuggestions {
            guard !trip.hasItem(named: suggestion.name, traveler: nil, pet: nil) else { continue }
            modelContext.insert(PackingItem(name: suggestion.name, categoryName: suggestion.category.rawValue, trip: trip))
            AnalyticsService.itemAdded(assigneeType: "everyone")
            didAddAnything = true
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            let traveler: Traveler?
            let pet: Pet?
            switch assignee {
            case .shared:
                traveler = nil
                pet = nil
            case .traveler(let t):
                traveler = t
                pet = nil
            case .pet(let p):
                traveler = nil
                pet = p
            }

            let item = PackingItem(name: trimmedName, categoryName: categoryName, quantity: quantity, trip: trip, traveler: traveler, pet: pet)
            modelContext.insert(item)
            let assigneeType: String
            switch assignee {
            case .shared: assigneeType = "everyone"
            case .traveler: assigneeType = "traveler"
            case .pet: assigneeType = "pet"
            }
            AnalyticsService.itemAdded(assigneeType: assigneeType)
            didAddAnything = true
        }

        if didAddAnything {
            Task { await TripSharingService.shared.resyncIfShared(trip) }
        }
        dismiss()
    }
}

enum AssigneeOption: Hashable {
    case shared
    case traveler(Traveler)
    case pet(Pet)
}

#Preview {
    let trip = Trip(name: "Preview Trip", destination: "Somewhere", startDate: .now, endDate: .now)
    return AddItemView(trip: trip)
        .modelContainer(for: [Trip.self, PackingItem.self, Luggage.self, Traveler.self, Pet.self, CustomCategory.self], inMemory: true)
}
