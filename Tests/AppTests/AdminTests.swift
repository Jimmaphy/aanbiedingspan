import Foundation
import XCTVapor
import XCTest

@testable import App

final class AdminTests: XCTestCase {
  func testAdminRequiresAuthenticationAndPublicPageGetsNoSessionCookie() async throws {
    let application = try await Application.make(.testing)
    try await configure(application)

    let publicResponse = try await application.sendRequest(.GET, "/") { _ in await Task.yield() }
    XCTAssertNil(publicResponse.headers.first(name: .setCookie))

    let adminResponse = try await application.sendRequest(.GET, "/admin") { _ in await Task.yield()
    }
    XCTAssertEqual(adminResponse.status, .seeOther)
    XCTAssertEqual(adminResponse.headers.first(name: .location), "/admin/login")

    try await application.asyncShutdown()
  }

  func testConfiguredAdminCanLogInWithCSRFProtectedForm() async throws {
    let application = try await Application.make(.testing)
    try await configure(application)
    application.adminAuth = .init(
      username: "beheerder", passwordHash: try Bcrypt.hash("sterk-wachtwoord", cost: 4),
      role: "editor")

    let loginPage = try await application.sendRequest(.GET, "/admin/login") { _ in
      await Task.yield()
    }
    XCTAssertEqual(loginPage.status, .ok)
    XCTAssertContains(loginPage.body.string, "Inloggen")
    let csrfToken = try XCTUnwrap(value(of: "csrfToken", in: loginPage.body.string))
    let firstCookie = try XCTUnwrap(loginPage.headers.first(name: .setCookie))
    XCTAssertContains(firstCookie, "HttpOnly")
    XCTAssertContains(firstCookie, "SameSite=Lax")
    let cookie = firstCookie.split(separator: ";", maxSplits: 1).first.map(String.init)!

    let rejected = try await application.sendRequest(
      .POST, "/admin/login",
      beforeRequest: { request in
        request.headers.contentType = .urlEncodedForm
        request.headers.replaceOrAdd(name: .cookie, value: cookie)
        request.body = .init(string: "username=beheerder&password=sterk-wachtwoord")
        await Task.yield()
      })
    XCTAssertEqual(rejected.status, .forbidden)

    let accepted = try await application.sendRequest(
      .POST, "/admin/login",
      beforeRequest: { request in
        request.headers.contentType = .urlEncodedForm
        request.headers.replaceOrAdd(name: .cookie, value: cookie)
        request.body = .init(
          string: "username=beheerder&password=sterk-wachtwoord&csrfToken=\(csrfToken)")
        await Task.yield()
      })
    XCTAssertEqual(accepted.status, .seeOther)
    XCTAssertEqual(accepted.headers.first(name: .location), "/admin")
    let authenticatedCookie = try XCTUnwrap(accepted.headers.first(name: .setCookie))
      .split(separator: ";", maxSplits: 1).first.map(String.init)!

    let dashboard = try await application.sendRequest(
      .GET, "/admin",
      beforeRequest: { request in
        request.headers.replaceOrAdd(name: .cookie, value: authenticatedCookie)
        await Task.yield()
      })
    XCTAssertEqual(dashboard.status, .ok)
    XCTAssertContains(dashboard.body.string, "Ingrediënten")
    XCTAssertContains(dashboard.body.string, "Aanbiedingen")
    XCTAssertContains(dashboard.body.string, "Receptbronnen")
    XCTAssertContains(dashboard.body.string, "Gerechtswensen")

    try await application.asyncShutdown()
  }

  func testAdminValidationUsesCanonicalRelationsWithoutMeasurements() throws {
    XCTAssertEqual(
      try AdminValidation.webURL("https://voorbeeld.nl/recept", field: "de receptlink"),
      "https://voorbeeld.nl/recept")
    XCTAssertThrowsError(try AdminValidation.webURL("javascript:alert(1)", field: "de receptlink"))
  }

  func testRecipeImagesAcceptOnlyBoundedRasterFormats() throws {
    let png = File(
      data: ByteBuffer(bytes: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      filename: "afbeelding.png")
    XCTAssertEqual(try RecipeImageStorage.validatedExtension(for: png), "png")

    let svg = File(data: "<svg></svg>", filename: "afbeelding.svg")
    XCTAssertThrowsError(try RecipeImageStorage.validatedExtension(for: svg))
  }

  private func value(of inputName: String, in html: String) -> String? {
    let marker = "name=\"\(inputName)\" value=\""
    guard let start = html.range(of: marker)?.upperBound,
      let end = html[start...].firstIndex(of: "\"")
    else { return nil }
    return String(html[start..<end])
  }
}
