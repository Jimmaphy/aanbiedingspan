import XCTest

@testable import App

final class SearchServiceTests: XCTestCase {
  func testIngredientScoreUsesThreeTwoOneZeroRules() throws {
    let service = SearchService(catalog: .demo)
    let filters = SearchFilters(
      dietaryPreferenceIDs: [],
      pantryIngredientIDs: ["tomato", "onion"],
      excludedIngredientIDs: [],
      supermarketIDs: ["albert-heijn"]
    )

    let result = try XCTUnwrap(
      service.search(filters: filters).first { $0.recipe.id == "tomato-spinach-pasta" })

    XCTAssertEqual(result.earnedScore, 6)
    XCTAssertEqual(result.maximumScore, 12)
    XCTAssertEqual(result.matchPercentage, 50)
    XCTAssertEqual(result.pantryCount, 2)
    XCTAssertEqual(result.offerCount, 2)
    XCTAssertEqual(result.neededCount, 1)
  }

  func testPantryIngredientOutweighsOfferIngredient() throws {
    let service = SearchService(catalog: .demo)
    let pantryOnly = try result(
      recipeID: "tomato-spinach-pasta",
      from: service.search(
        filters: .init(
          dietaryPreferenceIDs: [],
          pantryIngredientIDs: ["onion"],
          excludedIngredientIDs: [],
          supermarketIDs: []
        )
      )
    )
    let offerOnly = try result(
      recipeID: "tomato-spinach-pasta",
      from: service.search(
        filters: .init(
          dietaryPreferenceIDs: [],
          pantryIngredientIDs: [],
          excludedIngredientIDs: [],
          supermarketIDs: ["jumbo"]
        )
      )
    )

    XCTAssertEqual(pantryOnly.earnedScore, 2)
    XCTAssertEqual(offerOnly.earnedScore, 2, "Jumbo has two separate recipe ingredients on offer")
    XCTAssertEqual(pantryOnly.ingredients.first { $0.displayText == "Ui" }?.state, .pantry)
    XCTAssertEqual(offerOnly.ingredients.first { $0.displayText == "Pasta" }?.state, .offer)
  }

  func testDietaryPreferencesUseAllSelectedSemantics() throws {
    let service = SearchService(catalog: .demo)
    let results = try service.search(
      filters: .init(
        dietaryPreferenceIDs: ["vegan", "gluten-free"],
        pantryIngredientIDs: [],
        excludedIngredientIDs: [],
        supermarketIDs: []
      )
    )

    XCTAssertEqual(Set(results.map(\.recipe.id)), ["chickpea-curry", "pantry-rice-bowl"])
  }

  func testExcludedIngredientRemovesRecipe() throws {
    let service = SearchService(catalog: .demo)
    let results = try service.search(
      filters: .init(
        dietaryPreferenceIDs: [],
        pantryIngredientIDs: [],
        excludedIngredientIDs: ["coconut-milk"],
        supermarketIDs: []
      )
    )

    XCTAssertFalse(results.contains { $0.recipe.id == "chickpea-curry" })
  }

  func testConflictingIngredientIsRejected() {
    let service = SearchService(catalog: .demo)

    XCTAssertThrowsError(
      try service.search(
        filters: .init(
          dietaryPreferenceIDs: [],
          pantryIngredientIDs: ["tomato"],
          excludedIngredientIDs: ["tomato"],
          supermarketIDs: []
        )
      )
    ) { error in
      XCTAssertEqual(error as? SearchError, .conflictingIngredients(["tomato"]))
    }
  }

  private func result(recipeID: String, from results: [RankedRecipe]) throws -> RankedRecipe {
    try XCTUnwrap(results.first { $0.recipe.id == recipeID })
  }
}
