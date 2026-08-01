import Fluent
import Vapor

private struct ContactInformationForm: Content {
  let email: String
  let csrfToken: String?
}

struct SiteSettingsAdminController {
  func contactInformation(request: Request) async throws -> View {
    let record = try await ManagedContactInformation.find(
      ManagedContactInformation.singletonID, on: request.db)
    return try await request.view.render(
      "admin/contact-information",
      AdminContactInformationContext(
        username: try identity(request).username,
        csrfToken: AdminSession.csrfToken(for: request),
        email: record?.email ?? ""))
  }

  func updateContactInformation(request: Request) async throws -> Response {
    let form = try request.content.decode(ContactInformationForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let email = try AdminValidation.email(form.email)
    let actor = try identity(request).username

    try await request.db.transaction { database in
      if let record = try await ManagedContactInformation.find(
        ManagedContactInformation.singletonID, on: database)
      {
        record.email = email
        try await record.update(on: database)
        try await audit("update", actor: actor, on: database)
      } else {
        try await ManagedContactInformation(email: email).save(on: database)
        try await audit("create", actor: actor, on: database)
      }
    }
    return request.redirect(to: "/admin/contact-information")
  }

  private func identity(_ request: Request) throws -> AdminIdentity {
    guard let identity = AdminSession.identity(for: request) else { throw Abort(.unauthorized) }
    return identity
  }

  private func audit(_ action: String, actor: String, on database: any Database) async throws {
    try await AdminAuditEntry(
      actor: actor, action: action, entityType: "contact_information",
      entityID: ManagedContactInformation.singletonID
    ).save(on: database)
  }
}
