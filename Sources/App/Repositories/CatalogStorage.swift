import Vapor

private struct CatalogStorageKey: StorageKey {
  typealias Value = any CatalogRepository
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
