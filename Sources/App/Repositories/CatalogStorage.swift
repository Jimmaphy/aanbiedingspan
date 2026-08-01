import Fluent
import Vapor

private struct CatalogStorageKey: StorageKey {
  typealias Value = any CatalogRepository
}

extension CatalogRepository {
  func ingredients(on database: any Database) async throws -> [Ingredient] {
    try await load(on: database).ingredients
  }

  func supermarkets(on database: any Database) async throws -> [Supermarket] {
    try await load(on: database).supermarkets
  }
}

extension Application {
  var catalogRepository: any CatalogRepository {
    get {
      guard let repository = storage[CatalogStorageKey.self] else {
        fatalError("Catalog repository was not configured")
      }
      return repository
    }
    set {
      storage[CatalogStorageKey.self] = newValue
    }
  }
}
