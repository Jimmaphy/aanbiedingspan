import Foundation
import Vapor

struct AdminIdentity: Sendable {
  let username: String
  let role: String
}

struct AdminAuthConfiguration: Sendable {
  let username: String?
  let passwordHash: String?
  let role: String

  var isConfigured: Bool { username != nil && passwordHash != nil }
}

private struct AdminAuthKey: StorageKey { typealias Value = AdminAuthConfiguration }

extension Application {
  var adminAuth: AdminAuthConfiguration {
    get { storage[AdminAuthKey.self] ?? .init(username: nil, passwordHash: nil, role: "admin") }
    set { storage[AdminAuthKey.self] = newValue }
  }
}

enum AdminSession {
  static let usernameKey = "admin_username"
  static let roleKey = "admin_role"
  static let csrfKey = "admin_csrf"

  static func identity(for request: Request) -> AdminIdentity? {
    guard let username = request.session.data[usernameKey],
      let role = request.session.data[roleKey], ["admin", "editor"].contains(role)
    else { return nil }
    return .init(username: username, role: role)
  }

  static func csrfToken(for request: Request) -> String {
    if let token = request.session.data[csrfKey] { return token }
    let token = UUID().uuidString + UUID().uuidString
    request.session.data[csrfKey] = token
    return token
  }

  static func requireCSRF(_ submitted: String?, for request: Request) throws {
    guard let expected = request.session.data[csrfKey], let submitted,
      constantTimeEqual(expected, submitted)
    else { throw Abort(.forbidden, reason: "Je formulier is verlopen. Laad de pagina opnieuw.") }
  }

  private static func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
    let left = Array(lhs.utf8)
    let right = Array(rhs.utf8)
    guard left.count == right.count else { return false }
    return zip(left, right).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
  }
}

struct AdminGuardMiddleware: AsyncMiddleware {
  func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
    guard AdminSession.identity(for: request) != nil else {
      return request.redirect(to: "/admin/login")
    }
    return try await next.respond(to: request)
  }
}

struct AdminErrorMiddleware: AsyncMiddleware {
  func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
    do {
      return try await next.respond(to: request)
    } catch let abort as AbortError where abort.status.code >= 400 && abort.status.code < 500 {
      let view = try await request.view.render(
        "admin/error",
        AdminErrorContext(
          heading: abort.status == .notFound ? "Niet gevonden" : "Controleer je invoer",
          message: abort.reason,
          backPath: safeBackPath(request.headers.first(name: .init("Referer")))))
      return try await view.encodeResponse(status: abort.status, for: request)
    } catch {
      request.logger.report(error: error)
      let view = try await request.view.render(
        "admin/error",
        AdminErrorContext(
          heading: "Beheer is even niet beschikbaar",
          message: "Probeer het later opnieuw. Je invoer is niet verwerkt.", backPath: "/admin"))
      return try await view.encodeResponse(status: .internalServerError, for: request)
    }
  }

  private func safeBackPath(_ referer: String?) -> String {
    guard let referer, let url = URL(string: referer), url.path.hasPrefix("/admin") else {
      return "/admin"
    }
    return url.path
  }
}
