import Vapor

struct SearchRequest: Content, Sendable {
  var dietaryPreferences: [String]?
  var pantryIngredients: [String]?
  var excludedIngredients: [String]?
  var supermarkets: [String]?

  var filters: SearchFilters {
    SearchFilters(
      dietaryPreferenceIDs: Set(dietaryPreferences ?? []),
      pantryIngredientIDs: Set(pantryIngredients ?? []),
      excludedIngredientIDs: Set(excludedIngredients ?? []),
      supermarketIDs: Set(supermarkets ?? [])
    )
  }

  static let empty = SearchRequest()
}

struct SearchResponse: Content {
  let results: [RankedRecipe]
}

struct IngredientListResponse: Content {
  let ingredients: [Ingredient]
}

struct SupermarketListResponse: Content {
  let supermarkets: [Supermarket]
}
