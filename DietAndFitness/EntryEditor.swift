import SwiftUI
import SwiftData

/// Add or edit one row of the daily log.
/// Typing or picking a saved food (milk, eggs, a homemade meal) fills in the numbers.
/// Otherwise the numbers are optional and can be left blank.
struct EntryEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Food.name) private var foods: [Food]

    let day: Date
    let entry: LogEntry?

    @State private var name = ""
    @State private var servings = "1"
    @State private var macros = MacroDraft()
    @State private var saveAsFood = false
    /// Name of the saved food the numbers were last filled from, so typing doesn't refill over edits.
    @State private var filledFrom: String?

    init(day: Date, entry: LogEntry? = nil) {
        self.day = day
        self.entry = entry
        if let entry {
            _name = State(initialValue: entry.name)
            _servings = State(initialValue: entry.servings.editText)
            _macros = State(initialValue: MacroDraft(entry.perServing))
            _filledFrom = State(initialValue: entry.name.trimmed.lowercased())
        }
    }

    private var savedMatch: Food? {
        foods.first { $0.name.sameName(as: name) }
    }

    private var servingCount: Double { parseNumber(servings) ?? 1 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Food (e.g. Milk, Eggs, Stuff)", text: $name)
                        .textInputAutocapitalization(.words)
                    NumberRow(label: "Servings", text: $servings, placeholder: "1")
                } footer: {
                    if let food = savedMatch {
                        Text("Filled in from your saved \(food.isHomemade ? "homemade meal" : "food")\(food.servingNote.isEmpty ? "" : ". 1 serving = \(food.servingNote)").")
                    }
                }

                Section {
                    MacroFields(draft: $macros)
                } header: {
                    Text("Per serving")
                } footer: {
                    Text("Optional. Leave blank if you don't know.")
                }

                Section("Total") {
                    Text(macros.macros.times(servingCount).summary)
                }

                if entry == nil && savedMatch == nil && !name.trimmed.isEmpty {
                    Section {
                        Toggle("Save to My Foods", isOn: $saveAsFood)
                    } footer: {
                        Text("Next time, picking it fills these numbers in.")
                    }
                }

                FoodSuggestions(foods: foods, query: name) { fill(from: $0) }
            }
            .navigationTitle(entry == nil ? "Add Food" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmed.isEmpty)
                }
            }
            .onChange(of: name) { _, _ in
                if let food = savedMatch, filledFrom != food.name.trimmed.lowercased() {
                    fill(from: food)
                }
            }
        }
    }

    private func fill(from food: Food) {
        filledFrom = food.name.trimmed.lowercased()
        name = food.name
        macros = MacroDraft(food.macros)
    }

    private func save() {
        let perServing = macros.macros
        let cleanName = name.trimmed
        if let entry {
            entry.name = cleanName
            entry.servings = servingCount
            entry.perServing = perServing
        } else {
            context.insert(LogEntry(day: day, name: cleanName, servings: servingCount, perServing: perServing))
            if saveAsFood && savedMatch == nil {
                context.insert(Food(name: cleanName, macros: perServing))
            }
        }
        dismiss()
    }
}
