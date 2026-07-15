import Foundation

struct DietaryPreference: Codable, Hashable, Sendable {
  let id: String
  let name: String
}

struct Ingredient: Codable, Hashable, Sendable {
  let id: String
  let name: String
}

struct Supermarket: Codable, Hashable, Sendable {
  let id: String
  let name: String
}

struct RecipeIngredient: Codable, Hashable, Sendable {
  let ingredientID: String
  let displayText: String
  let weight: Double
}

struct Recipe: Codable, Hashable, Sendable {
  let id: String
  let title: String
  let summary: String
  let imagePath: String
  let sourceURL: String
  let sourceName: String
  let durationMinutes: Int
  let dietaryPreferenceIDs: Set<String>
  let ingredients: [RecipeIngredient]
}

struct Offer: Codable, Hashable, Sendable {
  let ingredientID: String
  let supermarketID: String
}

struct Catalog: Sendable {
  let dietaryPreferences: [DietaryPreference]
  let ingredients: [Ingredient]
  let supermarkets: [Supermarket]
  let recipes: [Recipe]
  let offers: [Offer]
}

extension Catalog {
  static let demo = Catalog(
    dietaryPreferences: [
      .init(id: "vegan", name: "Veganistisch"),
      .init(id: "vegetarian", name: "Vegetarisch"),
      .init(id: "gluten-free", name: "Glutenvrij"),
    ],
    ingredients: [
      .init(id: "chickpeas", name: "Kikkererwten"),
      .init(id: "coconut-milk", name: "Kokosmelk"),
      .init(id: "onion", name: "Ui"),
      .init(id: "pasta", name: "Pasta"),
      .init(id: "rice", name: "Rijst"),
      .init(id: "spinach", name: "Spinazie"),
      .init(id: "tomato", name: "Tomaat"),
    ],
    supermarkets: [
      .init(id: "albert-heijn", name: "Albert Heijn"),
      .init(id: "jumbo", name: "Jumbo"),
      .init(id: "lidl", name: "Lidl"),
    ],
    recipes: [
      .init(
        id: "tomato-spinach-pasta",
        title: "Pasta met tomaat en spinazie",
        summary: "Een snelle pasta met veel groente uit de voorraadkast.",
        imagePath: "/images/recipe-placeholder.svg",
        sourceURL: "https://example.com/recept/pasta-tomaat-spinazie",
        sourceName: "Demobron",
        durationMinutes: 25,
        dietaryPreferenceIDs: ["vegetarian"],
        ingredients: [
          .init(ingredientID: "pasta", displayText: "Pasta", weight: 1),
          .init(ingredientID: "tomato", displayText: "Tomaten", weight: 1),
          .init(ingredientID: "spinach", displayText: "Spinazie", weight: 1),
          .init(ingredientID: "onion", displayText: "Ui", weight: 1),
        ]
      ),
      .init(
        id: "chickpea-curry",
        title: "Kikkererwtencurry met rijst",
        summary: "Een zachte curry met kokosmelk en ingrediënten die lang goed blijven.",
        imagePath: "/images/recipe-placeholder.svg",
        sourceURL: "https://example.com/recept/kikkererwtencurry",
        sourceName: "Demobron",
        durationMinutes: 35,
        dietaryPreferenceIDs: ["vegan", "vegetarian", "gluten-free"],
        ingredients: [
          .init(ingredientID: "chickpeas", displayText: "Kikkererwten", weight: 1),
          .init(ingredientID: "coconut-milk", displayText: "Kokosmelk", weight: 1),
          .init(ingredientID: "rice", displayText: "Rijst", weight: 1),
          .init(ingredientID: "tomato", displayText: "Tomaat", weight: 1),
          .init(ingredientID: "onion", displayText: "Ui", weight: 1),
        ]
      ),
      .init(
        id: "pantry-rice-bowl",
        title: "Rijstkom met spinazie en tomaat",
        summary: "Een eenvoudige kom vol kleur, klaar in twintig minuten.",
        imagePath: "/images/recipe-placeholder.svg",
        sourceURL: "https://example.com/recept/rijstkom",
        sourceName: "Demobron",
        durationMinutes: 20,
        dietaryPreferenceIDs: ["vegan", "vegetarian", "gluten-free"],
        ingredients: [
          .init(ingredientID: "rice", displayText: "Rijst", weight: 1),
          .init(ingredientID: "spinach", displayText: "Spinazie", weight: 1),
          .init(ingredientID: "tomato", displayText: "Tomaat", weight: 1),
          .init(ingredientID: "chickpeas", displayText: "Kikkererwten", weight: 1),
        ]
      ),
    ],
    offers: [
      .init(ingredientID: "tomato", supermarketID: "albert-heijn"),
      .init(ingredientID: "spinach", supermarketID: "albert-heijn"),
      .init(ingredientID: "pasta", supermarketID: "jumbo"),
      .init(ingredientID: "spinach", supermarketID: "jumbo"),
      .init(ingredientID: "chickpeas", supermarketID: "lidl"),
    ]
  )
}
