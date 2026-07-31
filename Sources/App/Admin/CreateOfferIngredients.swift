import Fluent

struct CreateOfferIngredients: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema(ManagedOfferIngredient.schema)
      .id()
      .field(
        "offer_id", .uuid, .required,
        .references(ManagedOffer.schema, "id", onDelete: .cascade)
      )
      .field("ingredient_id", .uuid, .required, .references(ManagedIngredient.schema, "id"))
      .unique(on: "offer_id", "ingredient_id")
      .create()

    let existingOffers = try await ManagedOffer.query(on: database).all()
    for offer in existingOffers {
      try await ManagedOfferIngredient(
        offerID: offer.requireID(), ingredientID: offer.$legacyIngredient.id
      ).save(on: database)
    }
  }

  func revert(on database: Database) async throws {
    try await database.schema(ManagedOfferIngredient.schema).delete()
  }
}
