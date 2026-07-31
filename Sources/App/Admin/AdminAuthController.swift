import Vapor

struct AdminLoginForm: Content {
  let username: String
  let password: String
  let csrfToken: String?
}

struct AdminCSRFForm: Content { let csrfToken: String? }

struct AdminAuthController {
  func loginPage(request: Request) async throws -> View {
    if AdminSession.identity(for: request) != nil {
      throw Abort.redirect(to: "/admin")
    }
    return try await renderLogin(request: request, error: nil)
  }

  func login(request: Request) async throws -> Response {
    let form = try request.content.decode(AdminLoginForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let configuration = request.application.adminAuth
    guard let expectedUsername = configuration.username,
      let passwordHash = configuration.passwordHash,
      form.username == expectedUsername,
      (try? Bcrypt.verify(form.password, created: passwordHash)) == true
    else {
      let view = try await renderLogin(
        request: request, error: "De gebruikersnaam of het wachtwoord klopt niet.")
      return try await view.encodeResponse(status: .unauthorized, for: request)
    }
    request.session.id = nil
    request.session.data[AdminSession.usernameKey] = expectedUsername
    request.session.data[AdminSession.roleKey] = configuration.role
    request.session.data[AdminSession.csrfKey] = nil
    return request.redirect(to: "/admin")
  }

  func logout(request: Request) async throws -> Response {
    let form = try request.content.decode(AdminCSRFForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    request.session.destroy()
    return request.redirect(to: "/admin/login")
  }

  private func renderLogin(request: Request, error: String?) async throws -> View {
    try await request.view.render(
      "admin/login",
      AdminLoginContext(
        csrfToken: AdminSession.csrfToken(for: request), errorMessage: error,
        isConfigured: request.application.adminAuth.isConfigured
      ))
  }
}
