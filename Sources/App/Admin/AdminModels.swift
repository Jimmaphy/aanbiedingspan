import Fluent
import Vapor

final class ManagedContactInformation: Model, @unchecked Sendable {
  static let schema = "contact_information"
  static let singletonID = UUID(uuidString: "24488924-2545-4C79-98EC-057432763E84")!

  @ID(key: .id) var id: UUID?
  @Field(key: "email") var email: String
  @Timestamp(key: "created_at", on: .create) var createdAt: Date?
  @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

  init() {}

  init(email: String) {
    id = Self.singletonID
    self.email = email
  }
}

final class ManagedIngredient: Model, @unchecked Sendable {
  static let schema = "ingredients"
  @ID(key: .id) var id: UUID?
  @Field(key: "name") var name: String
  @Timestamp(key: "created_at", on: .create) var createdAt: Date?
  @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
  @Timestamp(key: "deleted_at", on: .delete) var deletedAt: Date?
  init() {}
  init(id: UUID? = nil, name: String) {
    self.id = id
    self.name = name
  }
}

final class ManagedSupermarket: Model, @unchecked Sendable {
  static let schema = "supermarkets"
  @ID(key: .id) var id: UUID?
  @Field(key: "name") var name: String
  @Timestamp(key: "created_at", on: .create) var createdAt: Date?
  @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
  @Timestamp(key: "deleted_at", on: .delete) var deletedAt: Date?
  init() {}
  init(id: UUID? = nil, name: String) {
    self.id = id
    self.name = name
  }
}

final class RecipeSourceRecord: Model, @unchecked Sendable {
  static let schema = "recipe_sources"
  @ID(key: .id) var id: UUID?
  @Field(key: "name") var name: String
  @OptionalField(key: "website_url") var websiteURL: String?
  @Timestamp(key: "created_at", on: .create) var createdAt: Date?
  @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
  @Timestamp(key: "deleted_at", on: .delete) var deletedAt: Date?
  init() {}
  init(id: UUID? = nil, name: String, websiteURL: String?) {
    self.id = id
    self.name = name
    self.websiteURL = websiteURL
  }
}

final class ManagedRecipe: Model, @unchecked Sendable {
  static let schema = "managed_recipes"
  @ID(key: .id) var id: UUID?
  @Field(key: "title") var title: String
  @Field(key: "summary") var summary: String
  @Field(key: "source_url") var sourceURL: String
  @Field(key: "duration_minutes") var durationMinutes: Int
  @Field(key: "is_published") var isPublished: Bool
  @OptionalField(key: "image_path") var imagePath: String?
  @Parent(key: "source_id") var source: RecipeSourceRecord
  @Siblings(through: ManagedRecipeIngredient.self, from: \.$recipe, to: \.$ingredient)
  var ingredients: [ManagedIngredient]
  @Siblings(through: ManagedRecipeDietaryPreference.self, from: \.$recipe, to: \.$preference)
  var dietaryPreferences: [ManagedDietaryPreference]
  @Timestamp(key: "created_at", on: .create) var createdAt: Date?
  @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
  @Timestamp(key: "deleted_at", on: .delete) var deletedAt: Date?
  init() {}
  init(
    id: UUID? = nil, title: String, summary: String, sourceURL: String,
    durationMinutes: Int, sourceID: UUID, imagePath: String? = nil, isPublished: Bool = false
  ) {
    self.id = id
    self.title = title
    self.summary = summary
    self.sourceURL = sourceURL
    self.durationMinutes = durationMinutes
    self.imagePath = imagePath
    self.isPublished = isPublished
    self.$source.id = sourceID
  }
}

final class ManagedDietaryPreference: Model, @unchecked Sendable {
  static let schema = "dietary_preferences"
  @ID(key: .id) var id: UUID?
  @Field(key: "name") var name: String
  @Field(key: "slug") var slug: String
  @Timestamp(key: "created_at", on: .create) var createdAt: Date?
  @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
  @Timestamp(key: "deleted_at", on: .delete) var deletedAt: Date?
  init() {}
  init(id: UUID? = nil, name: String, slug: String) {
    self.id = id
    self.name = name
    self.slug = slug
  }
}

final class ManagedRecipeDietaryPreference: Model, @unchecked Sendable {
  static let schema = "managed_recipe_dietary_preferences"
  @ID(key: .id) var id: UUID?
  @Parent(key: "recipe_id") var recipe: ManagedRecipe
  @Parent(key: "dietary_preference_id") var preference: ManagedDietaryPreference
  init() {}
  init(recipeID: UUID, preferenceID: UUID) {
    self.$recipe.id = recipeID
    self.$preference.id = preferenceID
  }
}

final class ManagedRecipeIngredient: Model, @unchecked Sendable {
  static let schema = "managed_recipe_ingredients"
  @ID(key: .id) var id: UUID?
  @Parent(key: "recipe_id") var recipe: ManagedRecipe
  @Parent(key: "ingredient_id") var ingredient: ManagedIngredient
  init() {}
  init(recipeID: UUID, ingredientID: UUID) {
    self.$recipe.id = recipeID
    self.$ingredient.id = ingredientID
  }
}

final class ManagedOffer: Model, @unchecked Sendable {
  static let schema = "offers"
  @ID(key: .id) var id: UUID?
  @Parent(key: "ingredient_id") var legacyIngredient: ManagedIngredient
  @Parent(key: "supermarket_id") var supermarket: ManagedSupermarket
  @OptionalField(key: "price_cents") var legacyPriceCents: Int?
  @Siblings(through: ManagedOfferIngredient.self, from: \.$offer, to: \.$ingredient)
  var ingredients: [ManagedIngredient]
  @Field(key: "valid_from") var validFrom: Date
  @Field(key: "valid_until") var validUntil: Date
  @Field(key: "is_published") var isPublished: Bool
  @Timestamp(key: "created_at", on: .create) var createdAt: Date?
  @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
  @Timestamp(key: "deleted_at", on: .delete) var deletedAt: Date?
  init() {}
  init(
    id: UUID? = nil, legacyIngredientID: UUID, supermarketID: UUID,
    validFrom: Date, validUntil: Date, isPublished: Bool = false
  ) {
    self.id = id
    self.$legacyIngredient.id = legacyIngredientID
    self.$supermarket.id = supermarketID
    self.legacyPriceCents = nil
    self.validFrom = validFrom
    self.validUntil = validUntil
    self.isPublished = isPublished
  }
}

final class ManagedOfferIngredient: Model, @unchecked Sendable {
  static let schema = "managed_offer_ingredients"
  @ID(key: .id) var id: UUID?
  @Parent(key: "offer_id") var offer: ManagedOffer
  @Parent(key: "ingredient_id") var ingredient: ManagedIngredient
  init() {}
  init(offerID: UUID, ingredientID: UUID) {
    self.$offer.id = offerID
    self.$ingredient.id = ingredientID
  }
}

final class AdminAuditEntry: Model, @unchecked Sendable {
  static let schema = "admin_audit_log"
  @ID(key: .id) var id: UUID?
  @Field(key: "actor") var actor: String
  @Field(key: "action") var action: String
  @Field(key: "entity_type") var entityType: String
  @Field(key: "entity_id") var entityID: UUID
  @Timestamp(key: "created_at", on: .create) var createdAt: Date?
  init() {}
  init(actor: String, action: String, entityType: String, entityID: UUID) {
    self.actor = actor
    self.action = action
    self.entityType = entityType
    self.entityID = entityID
  }
}
