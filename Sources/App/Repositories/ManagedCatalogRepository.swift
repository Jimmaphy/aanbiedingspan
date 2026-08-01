import Fluent
import Foundation

protocol CatalogRepository: Sendable {
  func load(on database: any Database) async throws -> Catalog
}

struct StaticCatalogRepository: CatalogRepository {
  let catalog: Catalog

  func load(on database: any Database) async throws -> Catalog {
    catalog
  }
}

struct ManagedCatalogRepository: CatalogRepository {
  static let ingredientLimit = 500
  static let supermarketLimit = 100
  static let preferenceLimit = 100
  static let sourceLimit = 200
  static let recipeLimit = 200
  static let offerLimit = 500

  let now: @Sendable () -> Date

  init(now: @escaping @Sendable () -> Date = Date.init) {
    self.now = now
  }

  func load(on database: any Database) async throws -> Catalog {
    let ingredients = try await ManagedIngredient.query(on: database)
      .sort(\.$name).limit(Self.ingredientLimit).all()
    let supermarkets = try await ManagedSupermarket.query(on: database)
      .sort(\.$name).limit(Self.supermarketLimit).all()
    let preferences = try await ManagedDietaryPreference.query(on: database)
      .sort(\.$name).limit(Self.preferenceLimit).all()
    let sourceIDs = Set(
      try await RecipeSourceRecord.query(on: database).sort(\.$name).limit(Self.sourceLimit).all()
        .map { try $0.requireID() })
    let supermarketIDs = Set(try supermarkets.map { try $0.requireID() })
    let recipes = try await ManagedRecipe.query(on: database)
      .filter(\.$isPublished == true)
      .filter(\.$source.$id ~~ sourceIDs)
      .with(\.$source).with(\.$ingredients).with(\.$dietaryPreferences)
      .sort(\.$title).limit(Self.recipeLimit).all()
    let instant = now()
    let offers = try await ManagedOffer.query(on: database)
      .filter(\.$isPublished == true)
      .filter(\.$validFrom <= instant)
      .filter(\.$validUntil >= instant)
      .filter(\.$supermarket.$id ~~ supermarketIDs)
      .with(\.$supermarket).with(\.$ingredients)
      .sort(\.$validUntil).limit(Self.offerLimit).all()

    return Catalog(
      dietaryPreferences: try preferences.map {
        DietaryPreference(id: try $0.requireID().uuidString, name: $0.name)
      },
      ingredients: try ingredients.map {
        Ingredient(id: try $0.requireID().uuidString, name: $0.name)
      },
      supermarkets: try supermarkets.map {
        Supermarket(id: try $0.requireID().uuidString, name: $0.name)
      },
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
          ingredients: try recipe.ingredients.sorted { $0.name < $1.name }.map {
            RecipeIngredient(
              ingredientID: try $0.requireID().uuidString, displayText: $0.name, weight: 1)
          })
      },
      offers: try offers.flatMap { offer in
        try offer.ingredients.map {
          Offer(
            ingredientID: try $0.requireID().uuidString,
            supermarketID: try offer.supermarket.requireID().uuidString)
        }
      })
  }
}
