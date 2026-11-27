import SwiftUI

extension Double {
    /// Short display form: 2508, 245.4, 0.25.
    var clean: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }

    /// Form for editing in a text field (no thousands separator).
    var editText: String {
        formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    func sameName(as other: String) -> Bool {
        trimmed.compare(other.trimmed, options: .caseInsensitive) == .orderedSame
    }
}

/// Reads a number typed by the user. Blank means "not entered".
func parseNumber(_ text: String) -> Double? {
    let cleaned = text.trimmed.replacingOccurrences(of: ",", with: ".")
    return cleaned.isEmpty ? nil : Double(cleaned)
}

/// The four macro fields as text, so they can be left blank.
struct MacroDraft: Equatable {
    var calories = ""
    var protein = ""
    var carbs = ""
    var fat = ""

    init() {}

    init(_ macros: Macros) {
        calories = macros.calories.editText
        protein = macros.protein.editText
        carbs = macros.carbs.editText
        fat = macros.fat.editText
    }

    var macros: Macros {
        Macros(calories: parseNumber(calories) ?? 0,
               protein: parseNumber(protein) ?? 0,
               carbs: parseNumber(carbs) ?? 0,
               fat: parseNumber(fat) ?? 0)
    }
}

/// A form row with a label on the left and a number field on the right.
struct NumberRow: View {
    let label: String
    @Binding var text: String
    var unit: String = ""
    var placeholder: String = "Optional"

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
            if !unit.isEmpty {
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)
            }
        }
    }
}

struct MacroFields: View {
    @Binding var draft: MacroDraft

    var body: some View {
        NumberRow(label: "Calories", text: $draft.calories, unit: "cal")
        NumberRow(label: "Protein", text: $draft.protein, unit: "g")
        NumberRow(label: "Carbs", text: $draft.carbs, unit: "g")
        NumberRow(label: "Fat", text: $draft.fat, unit: "g")
    }
}

/// Saved foods that match what has been typed. Tapping one fills in its numbers.
struct FoodSuggestions: View {
    let foods: [Food]
    let query: String
    let onPick: (Food) -> Void

    private var matches: [Food] {
        let q = query.trimmed
        let found = q.isEmpty ? foods : foods.filter { $0.name.localizedCaseInsensitiveContains(q) }
        return Array(found.filter { !$0.name.sameName(as: q) }.prefix(10))
    }

    var body: some View {
        if !matches.isEmpty {
            Section(query.trimmed.isEmpty ? "Pick a saved food" : "Matching saved foods") {
                ForEach(matches) { food in
                    Button { onPick(food) } label: { FoodRow(food: food) }
                        .tint(.primary)
                }
            }
        }
    }
}

/// A searchable list of everything in My Foods. Tapping one hands it back and closes the list.
struct SavedFoodPicker: View {
    @Environment(\.dismiss) private var dismiss
    let foods: [Food]
    let onPick: (Food) -> Void

    @State private var query = ""

    private var matches: [Food] {
        let q = query.trimmed
        return q.isEmpty ? foods : foods.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if foods.isEmpty {
                    ContentUnavailableView("No saved foods yet",
                                           systemImage: "fork.knife",
                                           description: Text("Foods you add in the Foods tab, or find online, show up here."))
                } else if matches.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(matches) { food in
                        Button {
                            onPick(food)
                            dismiss()
                        } label: { FoodRow(food: food) }
                        .tint(.primary)
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search My Foods")
            .navigationTitle("My Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct FoodRow: View {
    let food: Food

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(food.name)
                if food.isHomemade {
                    Image(systemName: "frying.pan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !food.servingNote.isEmpty {
                    Text(food.servingNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(food.macros.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// "‹  Nov 25, 2026  ›" row for moving between days.
struct DaySwitcher: View {
    @Binding var day: Date

    var body: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
            Spacer()
            DatePicker("Day", selection: $day, displayedComponents: .date)
                .labelsHidden()
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
        }
    }

    private func shift(_ days: Int) {
        let start = Calendar.current.startOfDay(for: day)
        day = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
    }
}

func dayRange(_ day: Date) -> (start: Date, end: Date) {
    let start = Calendar.current.startOfDay(for: day)
    let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
    return (start, end)
}
