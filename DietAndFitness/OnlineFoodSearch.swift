import SwiftUI
import SwiftData

// Search foods on the internet and save them to My Foods.
//
// The numbers come from USDA FoodData Central (https://fdc.nal.usda.gov), a free US government
// nutrition database. It has basic foods and ingredients (eggs, chicken breast, rice), common meals
// (lasagna, burritos) and packaged products by brand. Once a food is saved it lives on the phone
// like any other food, so the app only needs the internet while searching.

/// One serving size a food can be saved with, like "1 cup" = 245 g.
struct OnlinePortion: Identifiable, Hashable {
    var label: String
    var grams: Double
    var id: String { "\(label)-\(grams)" }

    var display: String {
        label == "100 g" ? label : "\(label) (\(grams.clean) g)"
    }
}

/// A food found online. The nutrition numbers are per 100 grams, the way the database stores them.
struct OnlineFood: Identifiable {
    var id: Int
    var name: String
    var brand: String
    var per100g: Macros
    var portions: [OnlinePortion]

    func macros(forGrams grams: Double) -> Macros {
        per100g.times(grams / 100)
    }
}

enum OnlineFoodKind: String, CaseIterable, Identifiable {
    case basic = "Foods & meals"
    case branded = "Brands"
    var id: String { rawValue }

    /// The database's names for its food lists.
    var dataTypes: String {
        switch self {
        case .basic: "Foundation,SR Legacy,Survey (FNDDS)"
        case .branded: "Branded"
        }
    }
}

enum OnlineFoodError: LocalizedError {
    case tooManySearches
    case badKey
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .tooManySearches:
            "Too many searches for now. Try again in a while, or add your own free key in Settings (gear button on the Log tab)."
        case .badKey:
            "The food database didn't accept the key in Settings. Check it, or clear it to use the shared one."
        case .server(let code):
            "The food database had a problem (error \(code)). Try again in a bit."
        }
    }
}

/// Talks to USDA FoodData Central.
enum FoodDataCentral {
    /// Works with no sign-up but allows only a few searches an hour per phone.
    /// A free personal key from https://fdc.nal.usda.gov/api-key-signup allows far more.
    static let sharedKey = "DEMO_KEY"
    static let keySetting = "fdcApiKey"

    static func search(_ query: String, kind: OnlineFoodKind) async throws -> [OnlineFood] {
        let savedKey = (UserDefaults.standard.string(forKey: keySetting) ?? "").trimmed
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: savedKey.isEmpty ? sharedKey : savedKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "dataType", value: kind.dataTypes),
            URLQueryItem(name: "requireAllWords", value: "true"),
            URLQueryItem(name: "pageSize", value: "30"),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        switch status {
        case 200: break
        case 429: throw OnlineFoodError.tooManySearches
        case 401, 403: throw OnlineFoodError.badKey
        default: throw OnlineFoodError.server(status)
        }

        let result = try JSONDecoder().decode(SearchResult.self, from: data)
        return (result.foods ?? []).compactMap(\.onlineFood)
    }

    // The parts of the database's answer that the app uses. Everything is optional
    // so that one odd food can't break a whole search.

    private struct SearchResult: Decodable {
        var foods: [SearchFood]?
    }

    private struct SearchFood: Decodable {
        var fdcId: Int?
        var description: String?
        var brandOwner: String?
        var brandName: String?
        var servingSize: Double?
        var servingSizeUnit: String?
        var householdServingFullText: String?
        var foodNutrients: [Nutrient]?
        var foodMeasures: [Measure]?

        var onlineFood: OnlineFood? {
            guard let fdcId, let description, !description.trimmed.isEmpty else { return nil }
            let nutrients = foodNutrients ?? []

            func amount(_ ids: [Int]) -> Double? {
                for id in ids {
                    if let found = nutrients.first(where: { $0.id == id && $0.isKnownUnit }), let value = found.value {
                        return value
                    }
                }
                return nil
            }

            let protein = amount([1003]) ?? 0
            let carbs = amount([1005, 1050]) ?? 0
            let fat = amount([1004, 1085]) ?? 0
            // Some basic foods only list "Atwater" energy instead of plain calories.
            let calories = amount([1008, 2047, 2048])
                ?? protein * Macros.proteinCaloriesPerGram + carbs * Macros.carbCaloriesPerGram + fat * Macros.fatCaloriesPerGram

            var portions: [OnlinePortion] = []
            let unit = (servingSizeUnit ?? "").lowercased()
            if let servingSize, servingSize > 0, ["g", "grm", "ml", "mlt"].contains(unit) {
                let household = (householdServingFullText ?? "").trimmed
                portions.append(OnlinePortion(label: household.isEmpty ? "1 serving" : household, grams: servingSize))
            }
            let measures = (foodMeasures ?? [])
                .filter { ($0.gramWeight ?? 0) > 0 && !($0.disseminationText ?? "").trimmed.isEmpty }
                .filter { $0.disseminationText?.localizedCaseInsensitiveContains("not specified") == false }
                .sorted { ($0.rank ?? .max) < ($1.rank ?? .max) }
                .prefix(6)
            for measure in measures {
                portions.append(OnlinePortion(label: measure.disseminationText!.trimmed, grams: measure.gramWeight!))
            }
            portions.append(OnlinePortion(label: "100 g", grams: 100))

            let brand = (brandName ?? brandOwner ?? "").trimmed
            return OnlineFood(id: fdcId,
                              name: tidyName(description),
                              brand: brand.isEmpty ? "" : tidyName(brand),
                              per100g: Macros(calories: calories, protein: protein, carbs: carbs, fat: fat),
                              portions: portions)
        }

        /// Packaged foods come in ALL CAPS ("GREEK YOGURT"); make them read normally.
        private func tidyName(_ text: String) -> String {
            let clean = text.trimmed
            return clean == clean.uppercased() ? clean.capitalized : clean
        }
    }

    private struct Nutrient: Decodable {
        var nutrientId: Int?
        var nutrientNumber: String?
        var unitName: String?
        var value: Double?

        /// The database's nutrient numbers, with the older numbering as a fallback.
        var id: Int? {
            if let nutrientId { return nutrientId }
            switch nutrientNumber {
            case "208": return 1008
            case "203": return 1003
            case "204": return 1004
            case "205": return 1005
            case "957": return 2047
            case "958": return 2048
            default: return nil
            }
        }

        /// Calories must be in kcal (not kJ) and macros in grams.
        var isKnownUnit: Bool {
            let unit = (unitName ?? "").uppercased()
            return unit == "KCAL" || unit == "G" || unit.isEmpty
        }
    }

    private struct Measure: Decodable {
        var disseminationText: String?
        var gramWeight: Double?
        var rank: Int?
    }
}

/// The search screen. Type a food, pick a result, choose a serving size and save it.
/// `onSaved` gets the new food, so the screen that opened this can fill it in.
struct OnlineFoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    var initialQuery = ""
    var onSaved: (Food) -> Void = { _ in }

    @State private var query = ""
    @State private var kind = OnlineFoodKind.basic
    @State private var results: [OnlineFood] = []
    @State private var searching = false
    @State private var searchedFor: String?
    @State private var errorText: String?

    init(initialQuery: String = "", onSaved: @escaping (Food) -> Void = { _ in }) {
        self.initialQuery = initialQuery
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search foods (e.g. chicken breast)", text: $query)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await search() } }
                        if searching { ProgressView() }
                    }
                    Picker("Kind", selection: $kind) {
                        ForEach(OnlineFoodKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                } footer: {
                    Text("Foods & meals has basic ingredients and common dishes. Brands has packaged products.")
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                } else if let searchedFor, results.isEmpty, !searching {
                    Section { Text("Nothing found for \u{201C}\(searchedFor)\u{201D}. Try fewer or simpler words.").foregroundStyle(.secondary) }
                }

                if !results.isEmpty {
                    Section {
                        ForEach(results) { food in
                            NavigationLink {
                                OnlineFoodDetail(food: food) { saved in
                                    onSaved(saved)
                                    dismiss()
                                }
                            } label: {
                                OnlineFoodRow(food: food)
                            }
                        }
                    } header: {
                        Text("Results")
                    } footer: {
                        Text("Nutrition data from USDA FoodData Central.")
                    }
                }
            }
            .navigationTitle("Search Online")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: kind) { _, _ in
                if searchedFor != nil { Task { await search() } }
            }
            .onAppear {
                if query.isEmpty && !initialQuery.trimmed.isEmpty {
                    query = initialQuery.trimmed
                    Task { await search() }
                }
            }
        }
    }

    private func search() async {
        let text = query.trimmed
        guard !text.isEmpty, !searching else { return }
        searching = true
        errorText = nil
        defer { searching = false }
        do {
            results = try await FoodDataCentral.search(text, kind: kind)
            searchedFor = text
        } catch let error as OnlineFoodError {
            results = []
            errorText = error.localizedDescription
        } catch {
            results = []
            errorText = "Couldn't reach the food database. Check your internet connection and try again."
        }
    }
}

private struct OnlineFoodRow: View {
    let food: OnlineFood

    var body: some View {
        let portion = food.portions[0]
        VStack(alignment: .leading, spacing: 2) {
            Text(food.name)
            if !food.brand.isEmpty {
                Text(food.brand).font(.caption).foregroundStyle(.secondary)
            }
            Text("\(portion.display): \(food.macros(forGrams: portion.grams).summary)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Pick the serving size for a food found online, rename it if you like, and save it to My Foods.
private struct OnlineFoodDetail: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]

    let food: OnlineFood
    let onSaved: (Food) -> Void

    @State private var name: String
    @State private var portion: OnlinePortion
    @State private var grams: String

    init(food: OnlineFood, onSaved: @escaping (Food) -> Void) {
        self.food = food
        self.onSaved = onSaved
        let first = food.portions[0]
        _name = State(initialValue: food.brand.isEmpty ? food.name : "\(food.brand) \(food.name)")
        _portion = State(initialValue: first)
        _grams = State(initialValue: first.grams.editText)
    }

    private var gramCount: Double { parseNumber(grams) ?? 0 }
    private var perServing: Macros { food.macros(forGrams: gramCount) }

    /// What "1 serving =" says in My Foods.
    private var servingNote: String {
        if gramCount == portion.grams { return portion.display }
        return "\(gramCount.clean) g"
    }

    private var nameTaken: Bool {
        foods.contains { $0.name.sameName(as: name) }
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name, axis: .vertical)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Save as")
            } footer: {
                if nameTaken {
                    Text("You already have a food with this name. Change it to save this one too.")
                        .foregroundStyle(.red)
                }
            }

            Section {
                if food.portions.count > 1 {
                    Picker("Serving", selection: $portion) {
                        ForEach(food.portions) { Text($0.display).tag($0) }
                    }
                }
                NumberRow(label: "Grams per serving", text: $grams, unit: "g", placeholder: "100")
            } header: {
                Text("1 serving")
            }

            Section("Per serving") {
                LabeledContent("Calories", value: perServing.calories.clean)
                LabeledContent("Protein", value: "\(perServing.protein.clean)g")
                LabeledContent("Carbs", value: "\(perServing.carbs.clean)g")
                LabeledContent("Fat", value: "\(perServing.fat.clean)g")
            }

            Section {
                Button(action: save) {
                    Label("Save to My Foods", systemImage: "square.and.arrow.down")
                }
                .disabled(name.trimmed.isEmpty || nameTaken || gramCount <= 0)
            } footer: {
                Text("Saved foods stay on your phone and work without internet.")
            }
        }
        .navigationTitle("Save Food")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: portion) { _, newValue in
            grams = newValue.grams.editText
        }
    }

    private func save() {
        var source = "From USDA FoodData Central (#\(food.id))"
        if !food.brand.isEmpty { source += ", \(food.brand)" }
        let saved = Food(name: name.trimmed, servingNote: servingNote, notes: source, macros: perServing)
        context.insert(saved)
        onSaved(saved)
    }
}

/// The free-key field shown in Settings.
struct OnlineFoodKeySetting: View {
    @AppStorage(FoodDataCentral.keySetting) private var key = ""

    var body: some View {
        Section {
            TextField("Optional", text: $key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())
        } header: {
            Text("Online food search key")
        } footer: {
            Text("Searching works without this, but only a few times an hour. A free key from fdc.nal.usda.gov/api-key-signup lets you search as much as you like.")
        }
    }
}
