import Fluent
import Foundation

protocol CatalogRepository: Sendable {
  func load(on database: any Database) async throws -> Catalog
  func ingredients(on database: any Database) async throws -> [Ingredient]
  func supermarkets(on database: any Database) async throws -> [Supermarket]
}

struct StaticCatalogRepository: CatalogRepository {
  let catalog: Catalog

  func load(on database: any Database) async throws -> Catalog {
    catalog
  }
}

struct ManagedCatalogRepository: CatalogRepository {
  struct Limits: Sendable {
    let ingredients: Int
    let supermarkets: Int
    let preferences: Int
    let recipes: Int
    let offerRecords: Int
    let offers: Int

    static let production = Limits(
      ingredients: 500, supermarkets: 100, preferences: 100,
      recipes: 200, offerRecords: 500, offers: 500)
  }

  let now: @Sendable () -> Date
  let limits: Limits

  init(
    now: @escaping @Sendable () -> Date = Date.init,
    limits: Limits = .production
  ) {
    self.now = now
    self.limits = limits
  }

  func load(on database: any Database) async throws -> Catalog {
    let ingredients = try await ingredientRecords(on: database)
    let supermarkets = try await supermarketRecords(on: database)
    let preferences = try await ManagedDietaryPreference.query(on: database)
      .sort(\.$name).sort(\.$id).limit(limits.preferences).all()
    let ingredientIDs = Set(try ingredients.map { try $0.requireID() })
    let supermarketIDs = Set(try supermarkets.map { try $0.requireID() })
    let preferenceIDs = Set(try preferences.map { try $0.requireID() })
    let loadedRecipes = try await ManagedRecipe.query(on: database)
      .filter(\.$isPublished == true)
      .with(\.$source).with(\.$ingredients).with(\.$dietaryPreferences)
      .sort(\.$title).sort(\.$id).limit(limits.recipes).all()
    let recipes = loadedRecipes.filter { recipe in
      let recipeIngredientIDs = Set(recipe.ingredients.compactMap(\.id))
      let recipePreferenceIDs = Set(recipe.dietaryPreferences.compactMap(\.id))
      return recipeIngredientIDs.isSubset(of: ingredientIDs)
        && recipePreferenceIDs.isSubset(of: preferenceIDs)
    }
    let instant = now()
    let offers = try await ManagedOffer.query(on: database)
      .filter(\.$isPublished == true)
      .filter(\.$validFrom <= instant)
      .filter(\.$validUntil >= instant)
      .filter(\.$supermarket.$id ~~ supermarketIDs)
      .with(\.$supermarket).with(\.$ingredients)
      .sort(\.$validUntil).sort(\.$id).limit(limits.offerRecords).all()

    return Catalog(
      dietaryPreferences: try preferences.map {
        DietaryPreference(id: try $0.requireID().uuidString, name: $0.name)
      },
      ingredients: try mapIngredients(ingredients),
      supermarkets: try mapSupermarkets(supermarkets),
      recipes: try recipes.map { recipe in
        Recipe(
          id: try recipe.requireID().uuidString,
          title: recipe.title,
          summary: recipe.summary,
          imagePath: recipe.imagePath ?? "/images/recipe-placeholder.svg",
          sourceURL: recipe.sourceURL,
          sourceName: recipe.source.name,
          durationMinutes: recipe.durationMinutes,
          dietaryPreferenceIDs: Set(
            try recipe.dietaryPreferences.map { try $0.requireID().uuidString }),
          ingredients: try recipe.ingredients.sorted(by: isIngredientOrderedBefore).map {
            RecipeIngredient(
              ingredientID: try $0.requireID().uuidString, displayText: $0.name, weight: 1)
          })
      },
      offers: try Array(
        offers.flatMap { offer in
          try offer.ingredients
            .filter { ingredientIDs.contains(try $0.requireID()) }
            .sorted(by: isIngredientOrderedBefore)
            .map {
              Offer(
                ingredientID: try $0.requireID().uuidString,
                supermarketID: try offer.supermarket.requireID().uuidString)
            }
        }.prefix(limits.offers))
    )
  }

  func ingredients(on database: any Database) async throws -> [Ingredient] {
    try mapIngredients(try await ingredientRecords(on: database))
  }

  func supermarkets(on database: any Database) async throws -> [Supermarket] {
    try mapSupermarkets(try await supermarketRecords(on: database))
  }

  private func ingredientRecords(on database: any Database) async throws
    -> [ManagedIngredient]
  {
    try await ManagedIngredient.query(on: database)
      .sort(\.$name).sort(\.$id).limit(limits.ingredients).all()
  }

  private func supermarketRecords(on database: any Database) async throws
    -> [ManagedSupermarket]
  {
    try await ManagedSupermarket.query(on: database)
      .sort(\.$name).sort(\.$id).limit(limits.supermarkets).all()
  }

  private func mapIngredients(_ records: [ManagedIngredient]) throws -> [Ingredient] {
    try records.map { Ingredient(id: try $0.requireID().uuidString, name: $0.name) }
  }

  private func mapSupermarkets(_ records: [ManagedSupermarket]) throws -> [Supermarket] {
    try records.map { Supermarket(id: try $0.requireID().uuidString, name: $0.name) }
  }

  private func isIngredientOrderedBefore(
    _ lhs: ManagedIngredient, _ rhs: ManagedIngredient
  ) -> Bool {
    if lhs.name != rhs.name { return lhs.name < rhs.name }
    return (lhs.id?.uuidString ?? "") < (rhs.id?.uuidString ?? "")
  }
}
