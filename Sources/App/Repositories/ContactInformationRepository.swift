import Fluent
import Vapor

protocol ContactInformationRepository: Sendable {
  func email(on database: any Database) async throws -> String?
}

struct StaticContactInformationRepository: ContactInformationRepository {
  let contactEmail: String?

  func email(on database: any Database) async throws -> String? {
    contactEmail
  }
}

struct ManagedContactInformationRepository: ContactInformationRepository {
  func email(on database: any Database) async throws -> String? {
    try await ManagedContactInformation.find(ManagedContactInformation.singletonID, on: database)?
      .email
  }
}

private struct ContactInformationRepositoryKey: StorageKey {
  typealias Value = any ContactInformationRepository
}

extension Application {
  var contactInformationRepository: any ContactInformationRepository {
    get {
      guard let repository = storage[ContactInformationRepositoryKey.self] else {
        fatalError("Contact information repository was not configured")
      }
      return repository
    }
    set { storage[ContactInformationRepositoryKey.self] = newValue }
  }
}
