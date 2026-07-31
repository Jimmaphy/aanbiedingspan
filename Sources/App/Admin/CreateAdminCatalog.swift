import Fluent

struct CreateAdminCatalog: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema(ManagedIngredient.schema)
      .id().field("name", .string, .required)
      .field("created_at", .datetime).field("updated_at", .datetime).field("deleted_at", .datetime)
      .create()
    try await database.schema(ManagedSupermarket.schema)
      .id().field("name", .string, .required)
      .field("created_at", .datetime).field("updated_at", .datetime).field("deleted_at", .datetime)
      .create()
    try await database.schema(RecipeSourceRecord.schema)
      .id().field("name", .string, .required).field("website_url", .string)
      .field("created_at", .datetime).field("updated_at", .datetime).field("deleted_at", .datetime)
      .create()
    try await database.schema(ManagedRecipe.schema)
      .id().field("title", .string, .required).field("summary", .string, .required)
      .field("source_url", .string, .required).field("duration_minutes", .int, .required)
      .field("source_id", .uuid, .required, .references(RecipeSourceRecord.schema, "id"))
      .field("created_at", .datetime).field("updated_at", .datetime).field("deleted_at", .datetime)
      .create()
    try await database.schema(ManagedRecipeIngredient.schema)
      .id().field(
        "recipe_id", .uuid, .required, .references(ManagedRecipe.schema, "id", onDelete: .cascade)
      )
      .field("ingredient_id", .uuid, .required, .references(ManagedIngredient.schema, "id"))
      .unique(on: "recipe_id", "ingredient_id").create()
    try await database.schema(ManagedOffer.schema)
      .id().field("ingredient_id", .uuid, .required, .references(ManagedIngredient.schema, "id"))
      .field("supermarket_id", .uuid, .required, .references(ManagedSupermarket.schema, "id"))
      .field("price_cents", .int).field("valid_from", .datetime, .required)
      .field("valid_until", .datetime, .required)
      .field("created_at", .datetime).field("updated_at", .datetime).field("deleted_at", .datetime)
      .create()
    try await database.schema(AdminAuditEntry.schema)
      .id().field("actor", .string, .required).field("action", .string, .required)
      .field("entity_type", .string, .required).field("entity_id", .uuid, .required)
      .field("created_at", .datetime).create()
  }

  func revert(on database: Database) async throws {
    try await database.schema(AdminAuditEntry.schema).delete()
    try await database.schema(ManagedOffer.schema).delete()
    try await database.schema(ManagedRecipeIngredient.schema).delete()
    try await database.schema(ManagedRecipe.schema).delete()
    try await database.schema(RecipeSourceRecord.schema).delete()
    try await database.schema(ManagedSupermarket.schema).delete()
    try await database.schema(ManagedIngredient.schema).delete()
  }
}
