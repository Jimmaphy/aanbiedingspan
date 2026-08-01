import Fluent

struct AddPublishingStatus: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema(ManagedRecipe.schema)
      .field("is_published", .bool, .required, .sql(.default(false)))
      .update()
    try await database.schema(ManagedOffer.schema)
      .field("is_published", .bool, .required, .sql(.default(false)))
      .update()
  }

  func revert(on database: Database) async throws {
    try await database.schema(ManagedOffer.schema).deleteField("is_published").update()
    try await database.schema(ManagedRecipe.schema).deleteField("is_published").update()
  }
}
