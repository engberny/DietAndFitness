import SwiftUI
import SwiftData

/// Saved foods and homemade meals that auto-fill the daily log.
struct FoodsView: View {
    enum NewKind: String, Identifiable {
        case food, meal, online
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]
    @State private var creating: NewKind?
    @State private var editing: Food?

    private var meals: [Food] { foods.filter(\.isHomemade) }
    private var plainFoods: [Food] { foods.filter { !$0.isHomemade } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if meals.isEmpty {
                        Text("No homemade meals yet.").foregroundStyle(.secondary)
                    }
                    ForEach(meals) { food in
                        Button { editing = food } label: { FoodRow(food: food) }
                            .tint(.primary)
                    }
                    .onDelete { offsets in
                        let doomed = offsets.map { meals[$0] }
                        for food in doomed { context.delete(food) }
                    }
                } header: {
                    Text("Homemade meals")
                }

                Section {
                    if plainFoods.isEmpty {
                        Text("No saved foods yet.").foregroundStyle(.secondary)
                    }
                    ForEach(plainFoods) { food in
                        Button { editing = food } label: { FoodRow(food: food) }
                            .tint(.primary)
                    }
                    .onDelete { offsets in
                        let doomed = offsets.map { plainFoods[$0] }
                        for food in doomed { context.delete(food) }
                    }
                } header: {
                    Text("Foods")
                } footer: {
                    Text("Numbers are per serving. Changing or deleting a food here doesn't change days you already logged.")
                }
            }
            .navigationTitle("My Foods")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { creating = .meal } label: { Label("New homemade meal", systemImage: "frying.pan") }
                        Button { creating = .food } label: { Label("New food", systemImage: "carrot") }
                        Button { creating = .online } label: { Label("Search online", systemImage: "globe") }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $creating) { kind in
                if kind == .online {
                    OnlineFoodSearchView()
                } else {
                    FoodEditor(food: nil, homemade: kind == .meal)
                }
            }
            .sheet(item: $editing) { food in FoodEditor(food: food, homemade: food.isHomemade) }
        }
    }
}

/// One ingredient while a homemade meal is being edited.
struct IngredientDraft: Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var servings = "1"
    var macros = MacroDraft()

    var total: Macros { macros.macros.times(parseNumber(servings) ?? 1) }
}

/// Create or edit a food or a homemade meal: name, calories, protein, carbs, fat.
/// A homemade meal can also list its ingredients, and then its numbers are the sum of them.
struct FoodEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Food.name) private var foods: [Food]

    let food: Food?
    let isHomemade: Bool

    @State private var name = ""
    @State private var servingNote = ""
    @State private var notes = ""
    @State private var macros = MacroDraft()
    @State private var ingredients: [IngredientDraft] = []
    @State private var editingIngredient: IngredientDraft?

    init(food: Food?, homemade: Bool) {
        self.food = food
        self.isHomemade = homemade
        if let food {
            _name = State(initialValue: food.name)
            _servingNote = State(initialValue: food.servingNote)
            _notes = State(initialValue: food.notes)
            _macros = State(initialValue: MacroDraft(food.macros))
            _ingredients = State(initialValue: food.sortedIngredients.map {
                IngredientDraft(name: $0.name, servings: $0.servings.editText, macros: MacroDraft($0.perServing))
            })
        } else if homemade {
            _servingNote = State(initialValue: "whole batch")
        }
    }

    private var usesIngredients: Bool { isHomemade && !ingredients.isEmpty }
    private var ingredientTotal: Macros { ingredients.sumMacros { $0.total } }

    private var nameTaken: Bool {
        foods.contains { $0 !== food && $0.name.sameName(as: name) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(isHomemade ? "Meal name (e.g. Stuff)" : "Food name (e.g. Milk)", text: $name)
                        .textInputAutocapitalization(.words)
                    HStack {
                        Text("1 serving =")
                            .foregroundStyle(.secondary)
                        TextField(isHomemade ? "whole batch" : "1 cup", text: $servingNote)
                    }
                    if isHomemade {
                        TextField("Notes (e.g. what went in)", text: $notes, axis: .vertical)
                    }
                } footer: {
                    if nameTaken {
                        Text("You already have a food with this name.")
                            .foregroundStyle(.red)
                    }
                }

                if isHomemade {
                    Section {
                        ForEach(ingredients) { item in
                            Button { editingIngredient = item } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name.trimmed.isEmpty ? "Ingredient" : item.name)
                                    Text("\((parseNumber(item.servings) ?? 1).clean) × · \(item.total.summary)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                        }
                        .onDelete { ingredients.remove(atOffsets: $0) }
                        Button { editingIngredient = IngredientDraft() } label: {
                            Label("Add ingredient", systemImage: "plus.circle.fill")
                        }
                    } header: {
                        Text("Ingredients")
                    } footer: {
                        Text("Optional. List what went into the batch and the totals add up for you. Or skip this and type the totals below.")
                    }
                }

                if usesIngredients {
                    Section("Whole meal totals") {
                        LabeledContent("Calories", value: ingredientTotal.calories.clean)
                        LabeledContent("Protein", value: "\(ingredientTotal.protein.clean)g")
                        LabeledContent("Carbs", value: "\(ingredientTotal.carbs.clean)g")
                        LabeledContent("Fat", value: "\(ingredientTotal.fat.clean)g")
                    }
                } else {
                    Section {
                        MacroFields(draft: $macros)
                    } header: {
                        Text(isHomemade ? "Whole meal totals" : "Per serving")
                    }
                }
            }
            .navigationTitle(food == nil ? (isHomemade ? "New Homemade Meal" : "New Food") : name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmed.isEmpty || nameTaken)
                }
            }
            .sheet(item: $editingIngredient) { draft in
                IngredientEditor(draft: draft, foods: foods.filter { !$0.isHomemade }) { saved in
                    if let index = ingredients.firstIndex(where: { $0.id == saved.id }) {
                        ingredients[index] = saved
                    } else {
                        ingredients.append(saved)
                    }
                }
            }
        }
    }

    private func save() {
        let target: Food
        if let food {
            target = food
        } else {
            target = Food(name: name.trimmed, isHomemade: isHomemade)
            context.insert(target)
        }
        target.name = name.trimmed
        target.servingNote = servingNote.trimmed
        target.notes = notes.trimmed
        target.macros = usesIngredients ? ingredientTotal : macros.macros

        if isHomemade {
            for old in target.ingredients { context.delete(old) }
            target.ingredients = []
            for (index, draft) in ingredients.enumerated() {
                let ingredient = Ingredient(name: draft.name.trimmed,
                                            servings: parseNumber(draft.servings) ?? 1,
                                            perServing: draft.macros.macros,
                                            order: index)
                context.insert(ingredient)
                target.ingredients.append(ingredient)
            }
        }
        dismiss()
    }
}

/// Add or edit one ingredient of a homemade meal. Picking a saved food fills in its numbers.
struct IngredientEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: IngredientDraft
    let foods: [Food]
    let onSave: (IngredientDraft) -> Void
    @State private var searchingOnline = false

    init(draft: IngredientDraft, foods: [Food], onSave: @escaping (IngredientDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.foods = foods
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ingredient (e.g. Chicken)", text: $draft.name)
                        .textInputAutocapitalization(.words)
                    NumberRow(label: "Servings", text: $draft.servings, placeholder: "1")
                }
                Section {
                    MacroFields(draft: $draft.macros)
                } header: {
                    Text("Per serving")
                }
                Section("Total") {
                    Text(draft.total.summary)
                }
                FoodSuggestions(foods: foods, query: draft.name) { food in
                    draft.name = food.name
                    draft.macros = MacroDraft(food.macros)
                }
                Section {
                    Button { searchingOnline = true } label: {
                        Label("Search online", systemImage: "globe")
                    }
                } footer: {
                    Text("Find this ingredient's numbers online and save it to My Foods.")
                }
            }
            .sheet(isPresented: $searchingOnline) {
                OnlineFoodSearchView(initialQuery: draft.name) { food in
                    draft.name = food.name
                    draft.macros = MacroDraft(food.macros)
                }
            }
            .navigationTitle("Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmed.isEmpty)
                }
            }
        }
    }
}
