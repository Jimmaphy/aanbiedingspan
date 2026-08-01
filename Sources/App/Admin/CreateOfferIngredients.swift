import Fluent
import Foundation

struct CreateOfferIngredients: AsyncMigration {
  final class LegacyOffer: Model, @unchecked Sendable {
    static let schema = ManagedOffer.schema

    @ID(key: .id) var id: UUID?
    @Parent(key: "ingredient_id") var ingredient: ManagedIngredient
    @Parent(key: "supermarket_id") var supermarket: ManagedSupermarket
    @OptionalField(key: "price_cents") var priceCents: Int?
    @Field(key: "valid_from") var validFrom: Date
    @Field(key: "valid_until") var validUntil: Date
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?
    @Timestamp(key: "deleted_at", on: .delete) var deletedAt: Date?

    init() {}

    init(
      id: UUID? = nil, ingredientID: UUID, supermarketID: UUID,
      validFrom: Date, validUntil: Date
    ) {
      self.id = id
      self.$ingredient.id = ingredientID
      self.$supermarket.id = supermarketID
      priceCents = nil
      self.validFrom = validFrom
      self.validUntil = validUntil
    }
  }

  func prepare(on database: Database) async throws {
    try await database.transaction { transactionalDatabase in
      try await transactionalDatabase.schema(ManagedOfferIngredient.schema)
        .id()
        .field(
          "offer_id", .uuid, .required,
          .references(ManagedOffer.schema, "id", onDelete: .cascade)
        )
        .field("ingredient_id", .uuid, .required, .references(ManagedIngredient.schema, "id"))
        .unique(on: "offer_id", "ingredient_id")
        .create()

      let batchSize = 100
      var offset = 0
      while true {
        let offers = try await LegacyOffer.query(on: transactionalDatabase)
          .sort(\.$id).offset(offset).limit(batchSize).all()
        for offer in offers {
          try await ManagedOfferIngredient(
            offerID: offer.requireID(), ingredientID: offer.$ingredient.id
          ).save(on: transactionalDatabase)
        }
        guard offers.count == batchSize else { break }
        offset += batchSize
      }
    }
  }

  func revert(on database: Database) async throws {
    try await database.schema(ManagedOfferIngredient.schema).delete()
  }
}
