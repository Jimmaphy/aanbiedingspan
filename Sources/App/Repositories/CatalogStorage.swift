import Vapor

private struct CatalogStorageKey: StorageKey {
  typealias Value = Catalog
}

extension Application {
  var catalog: Catalog {
    get {
      guard let catalog = storage[CatalogStorageKey.self] else {
        fatalError("Catalog was not configured")
      }
      return catalog
    }
    set {
      storage[CatalogStorageKey.self] = newValue
    }
  }
}
