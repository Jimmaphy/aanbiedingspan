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

struct RecipeCardContext: Encodable {
  let id: String
  let title: String
  let summary: String
  let imagePath: String
  let sourceURL: String
  let sourceName: String
  let dietaryPreferences: [String]
  let matchPercentage: Int
  let detailsHTML: String

  static func makeDetailsHTML(
    durationMinutes: Int,
    ingredientCount: Int,
    pantryCount: Int,
    offerCount: Int
  ) -> String {
    let ingredientLabel = ingredientCount == 1 ? "ingrediënt" : "ingrediënten"
    let duration = "<strong>\(durationMinutes) minuten</strong>"
    let ingredients = "<strong>\(ingredientCount) \(ingredientLabel)"

    switch (pantryCount > 0, offerCount > 0) {
    case (false, false):
      return "\(duration) werk met \(ingredients).</strong>"
    case (false, true):
      return
        "\(duration) werk met \(ingredients)</strong>, waarvan <strong>\(offerCount) in de aanbieding.</strong>"
    case (true, false):
      return
        "\(duration) werk met \(ingredients)</strong>, waarvan <strong>\(pantryCount) in huis.</strong>"
    case (true, true):
      return
        "\(duration) werk met \(ingredients)</strong>, waarvan <strong>\(pantryCount) in huis</strong> en <strong>\(offerCount) in de aanbieding.</strong>"
    }
  }
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
  let catalogNotice: String?
  let showsExternalLinkNotice: Bool

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
        dietaryPreferences: result.recipe.dietaryPreferenceIDs.compactMap { preferenceNames[$0] }
          .sorted(),
        matchPercentage: result.matchPercentage,
        detailsHTML: RecipeCardContext.makeDetailsHTML(
          durationMinutes: result.recipe.durationMinutes,
          ingredientCount: result.ingredients.count,
          pantryCount: result.pantryCount,
          offerCount: result.offerCount
        )
      )
    }
    searchState = hasSearched ? "results" : "wizard"
    resultsHiddenAttribute = hasSearched ? "" : "hidden"
    recipeGridHiddenAttribute = results.isEmpty ? "hidden" : ""
    emptyStateHiddenAttribute = results.isEmpty ? "" : "hidden"
    resultCount = results.count
    catalogNotice =
      catalog.ingredients.isEmpty || catalog.supermarkets.isEmpty
      ? "Er staan nog niet genoeg keuzes klaar om te zoeken. Probeer het later opnieuw."
      : nil
    showsExternalLinkNotice = hasSearched && !results.isEmpty
  }

}

struct InformationPageContext: Encodable {
  let pageTitle: String
  let contactEmail: String?

  init(pageTitle: String, contactEmail: String? = nil) {
    self.pageTitle = pageTitle
    self.contactEmail = contactEmail
  }
}
