import Foundation

struct SelectionOptionContext: Encodable {
  let id: String
  let name: String
  let checkedAttribute: String
}

struct IngredientOptionContext: Encodable {
  let id: String
  let name: String
  let pantryCheckedAttribute: String
  let excludedCheckedAttribute: String
}

struct IngredientMatchContext: Encodable {
  let displayText: String
  let statusClass: String
  let statusText: String
}

struct RecipeCardContext: Encodable {
  let id: String
  let title: String
  let summary: String
  let imagePath: String
  let sourceURL: String
  let sourceName: String
  let durationMinutes: Int
  let dietaryPreferences: [String]
  let matchPercentage: Int
  let pantryCount: Int
  let offerCount: Int
  let neededCount: Int
  let ingredients: [IngredientMatchContext]
}

struct SearchPageContext: Encodable {
  let pageTitle: String
  let dietaryPreferences: [SelectionOptionContext]
  let ingredients: [IngredientOptionContext]
  let supermarkets: [SelectionOptionContext]
  let results: [RecipeCardContext]
  let searchState: String
  let resultsHiddenAttribute: String
  let recipeGridHiddenAttribute: String
  let emptyStateHiddenAttribute: String
  let resultCount: Int

  init(catalog: Catalog, request: SearchRequest, results: [RankedRecipe], hasSearched: Bool) {
    let filters = request.filters
    let preferenceNames = Dictionary(
      uniqueKeysWithValues: catalog.dietaryPreferences.map { ($0.id, $0.name) })

    pageTitle =
      hasSearched ? "Recepten die bij je keuken passen" : "Vind een recept met wat je al hebt"
    dietaryPreferences = catalog.dietaryPreferences.map {
      SelectionOptionContext(
        id: $0.id,
        name: $0.name,
        checkedAttribute: filters.dietaryPreferenceIDs.contains($0.id) ? "checked" : ""
      )
    }
    ingredients = catalog.ingredients.map {
      IngredientOptionContext(
        id: $0.id,
        name: $0.name,
        pantryCheckedAttribute: filters.pantryIngredientIDs.contains($0.id) ? "checked" : "",
        excludedCheckedAttribute: filters.excludedIngredientIDs.contains($0.id) ? "checked" : ""
      )
    }
    supermarkets = catalog.supermarkets.map {
      SelectionOptionContext(
        id: $0.id,
        name: $0.name,
        checkedAttribute: filters.supermarketIDs.contains($0.id) ? "checked" : ""
      )
    }
    self.results = results.map { result in
      RecipeCardContext(
        id: result.recipe.id,
        title: result.recipe.title,
        summary: result.recipe.summary,
        imagePath: result.recipe.imagePath,
        sourceURL: result.recipe.sourceURL,
        sourceName: result.recipe.sourceName,
        durationMinutes: result.recipe.durationMinutes,
        dietaryPreferences: result.recipe.dietaryPreferenceIDs.compactMap { preferenceNames[$0] }
          .sorted(),
        matchPercentage: result.matchPercentage,
        pantryCount: result.pantryCount,
        offerCount: result.offerCount,
        neededCount: result.neededCount,
        ingredients: result.ingredients.map { ingredient in
          let presentation = Self.presentation(for: ingredient.state)
          return IngredientMatchContext(
            displayText: ingredient.displayText,
            statusClass: presentation.className,
            statusText: presentation.text
          )
        }
      )
    }
    searchState = hasSearched ? "results" : "wizard"
    resultsHiddenAttribute = hasSearched ? "" : "hidden"
    recipeGridHiddenAttribute = results.isEmpty ? "hidden" : ""
    emptyStateHiddenAttribute = results.isEmpty ? "" : "hidden"
    resultCount = results.count
  }

  private static func presentation(for state: IngredientMatchState) -> (
    className: String, text: String
  ) {
    switch state {
    case .pantryAndOffer: return ("status-combined", "In huis én aanbieding")
    case .pantry: return ("status-pantry", "In huis")
    case .offer: return ("status-offer", "In aanbieding")
    case .needed: return ("status-needed", "Nog nodig")
    }
  }
}

struct InformationPageContext: Encodable {
  let pageTitle: String
}
