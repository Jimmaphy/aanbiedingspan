import Vapor

struct SecurityHeadersMiddleware: AsyncMiddleware {
  func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
    let response = try await next.respond(to: request)
    response.headers.replaceOrAdd(name: .xContentTypeOptions, value: "nosniff")
    response.headers.replaceOrAdd(name: .xFrameOptions, value: "DENY")
    response.headers.replaceOrAdd(
      name: .init("Referrer-Policy"), value: "strict-origin-when-cross-origin")
    response.headers.replaceOrAdd(
      name: .contentSecurityPolicy,
      value:
        "default-src 'self'; img-src 'self'; style-src 'self'; script-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
    )
    response.headers.replaceOrAdd(
      name: .init("Permissions-Policy"), value: "geolocation=(), camera=(), microphone=()")
    return response
  }
}
