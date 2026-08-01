import Fluent

struct CreateContactInformation: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema(ManagedContactInformation.schema)
      .id()
      .field("email", .string, .required)
      .field("created_at", .datetime)
      .field("updated_at", .datetime)
      .create()
  }

  func revert(on database: Database) async throws {
    try await database.schema(ManagedContactInformation.schema).delete()
  }
}
