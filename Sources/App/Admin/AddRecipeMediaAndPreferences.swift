import Fluent

struct AddRecipeMediaAndPreferences: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema(ManagedRecipe.schema)
      .field("image_path", .string)
      .update()
    try await database.schema(ManagedDietaryPreference.schema)
      .id()
      .field("name", .string, .required)
      .field("slug", .string, .required)
      .field("created_at", .datetime)
      .field("updated_at", .datetime)
      .field("deleted_at", .datetime)
      .unique(on: "slug")
      .create()
    try await database.schema(ManagedRecipeDietaryPreference.schema)
      .id()
      .field(
        "recipe_id", .uuid, .required,
        .references(ManagedRecipe.schema, "id", onDelete: .cascade)
      )
      .field(
        "dietary_preference_id", .uuid, .required,
        .references(ManagedDietaryPreference.schema, "id")
      )
      .unique(on: "recipe_id", "dietary_preference_id")
      .create()

    for preference in [
      ManagedDietaryPreference(name: "Veganistisch", slug: "vegan"),
      ManagedDietaryPreference(name: "Vegetarisch", slug: "vegetarian"),
      ManagedDietaryPreference(name: "Glutenvrij", slug: "gluten-free"),
    ] {
      try await preference.save(on: database)
    }
  }

  func revert(on database: Database) async throws {
    try await database.schema(ManagedRecipeDietaryPreference.schema).delete()
    try await database.schema(ManagedDietaryPreference.schema).delete()
    try await database.schema(ManagedRecipe.schema).deleteField("image_path").update()
  }
}
