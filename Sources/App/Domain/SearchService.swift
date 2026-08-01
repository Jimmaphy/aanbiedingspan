import Foundation

struct SearchFilters: Equatable, Sendable {
  let dietaryPreferenceIDs: Set<String>
  let pantryIngredientIDs: Set<String>
  let excludedIngredientIDs: Set<String>
  let supermarketIDs: Set<String>
}

enum IngredientMatchState: String, Codable, Sendable {
  case pantryAndOffer
  case pantry
  case offer
  case needed
}

struct IngredientMatch: Codable, Sendable {
  let displayText: String
  let state: IngredientMatchState
}

struct RankedRecipe: Codable, Sendable {
  let recipe: Recipe
  let matchPercentage: Int
  let earnedScore: Double
  let maximumScore: Double
  let pantryCount: Int
  let offerCount: Int
  let neededCount: Int
  let ingredients: [IngredientMatch]
}

enum SearchError: Error, Equatable {
  case conflictingIngredients(Set<String>)
}

struct SearchService: Sendable {
  let catalog: Catalog

  func search(filters: SearchFilters) throws -> [RankedRecipe] {
    let conflicts = filters.pantryIngredientIDs.intersection(filters.excludedIngredientIDs)
    guard conflicts.isEmpty else {
      throw SearchError.conflictingIngredients(conflicts)
    }
    let offeredIngredientIDs = Set(
      catalog.offers.lazy
        .filter { filters.supermarketIDs.contains($0.supermarketID) }
        .map(\.ingredientID))

    return catalog.recipes
      .filter { recipe in
        recipe.dietaryPreferenceIDs.isSuperset(of: filters.dietaryPreferenceIDs)
          && Set(recipe.ingredients.map(\.ingredientID)).isDisjoint(
            with: filters.excludedIngredientIDs)
      }
      .map { rank(recipe: $0, filters: filters, offeredIngredientIDs: offeredIngredientIDs) }
      .sorted(by: isOrderedBefore)
  }

  private func rank(
    recipe: Recipe, filters: SearchFilters, offeredIngredientIDs: Set<String>
  ) -> RankedRecipe {
    var earnedScore = 0.0
    var maximumScore = 0.0
    var pantryCount = 0
    var offerCount = 0
    var neededCount = 0

    let ingredientMatches = recipe.ingredients.map { recipeIngredient in
      let isInPantry = filters.pantryIngredientIDs.contains(recipeIngredient.ingredientID)
      let isOnOffer = offeredIngredientIDs.contains(recipeIngredient.ingredientID)

      let state: IngredientMatchState
      let statusScore: Double
      switch (isInPantry, isOnOffer) {
      case (true, true):
        state = .pantryAndOffer
        statusScore = 3
        pantryCount += 1
        offerCount += 1
      case (true, false):
        state = .pantry
        statusScore = 2
        pantryCount += 1
      case (false, true):
        state = .offer
        statusScore = 1
        offerCount += 1
      case (false, false):
        state = .needed
        statusScore = 0
        neededCount += 1
      }

      earnedScore += recipeIngredient.weight * statusScore
      maximumScore += recipeIngredient.weight * 3
      return IngredientMatch(displayText: recipeIngredient.displayText, state: state)
    }

    let percentage = maximumScore == 0 ? 0 : Int((100 * earnedScore / maximumScore).rounded(.down))
    return RankedRecipe(
      recipe: recipe,
      matchPercentage: percentage,
      earnedScore: earnedScore,
      maximumScore: maximumScore,
      pantryCount: pantryCount,
      offerCount: offerCount,
      neededCount: neededCount,
      ingredients: ingredientMatches
    )
  }

  private func isOrderedBefore(_ lhs: RankedRecipe, _ rhs: RankedRecipe) -> Bool {
    if lhs.matchPercentage != rhs.matchPercentage {
      return lhs.matchPercentage > rhs.matchPercentage
    }
    if lhs.pantryCount != rhs.pantryCount {
      return lhs.pantryCount > rhs.pantryCount
    }
    if lhs.neededCount != rhs.neededCount {
      return lhs.neededCount < rhs.neededCount
    }
    if lhs.recipe.durationMinutes != rhs.recipe.durationMinutes {
      return lhs.recipe.durationMinutes < rhs.recipe.durationMinutes
    }
    let titleComparison = lhs.recipe.title.localizedStandardCompare(rhs.recipe.title)
    if titleComparison != .orderedSame {
      return titleComparison == .orderedAscending
    }
    return lhs.recipe.id < rhs.recipe.id
  }
}
