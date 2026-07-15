import XCTVapor
import XCTest

@testable import App

final class RouteTests: XCTestCase {
  func testPublicPagesRenderDutchContentAndSecurityHeaders() async throws {
    let application = try await Application.make(.testing)
    try await configure(application)

    let homeResponse = try await application.sendRequest(.GET, "/") { _ in await Task.yield() }
    XCTAssertEqual(homeResponse.status, .ok)
    XCTAssertContains(homeResponse.body.string, "Vind een recept met wat je al hebt")
    XCTAssertContains(homeResponse.body.string, "Onthoud mijn keuzes voor een volgend bezoek")
    XCTAssertEqual(homeResponse.headers.first(name: .xFrameOptions), "DENY")

    let aboutResponse = try await application.sendRequest(.GET, "/about") { _ in await Task.yield()
    }
    XCTAssertEqual(aboutResponse.status, .ok)
    XCTAssertContains(aboutResponse.body.string, "Zo komt je match tot stand")

    let privacyResponse = try await application.sendRequest(.GET, "/privacy") { _ in
      await Task.yield()
    }
    XCTAssertEqual(privacyResponse.status, .ok)
    XCTAssertContains(privacyResponse.body.string, "Jouw keuzes blijven van jou")

    try await application.asyncShutdown()
  }

  func testSearchReturnsRankedRecipes() async throws {
    let application = try await Application.make(.testing)
    try await configure(application)

    let request = SearchRequest(
      dietaryPreferences: ["vegan"],
      pantryIngredients: ["chickpeas", "coconut-milk"],
      excludedIngredients: [],
      supermarkets: ["lidl"]
    )
    let response = try await application.sendRequest(
      .POST, "/api/search",
      beforeRequest: { requestMessage in
        try requestMessage.content.encode(request)
        await Task.yield()
      })
    XCTAssertEqual(response.status, .ok)
    let payload = try response.content.decode(SearchResponse.self)
    XCTAssertEqual(payload.results.first?.recipe.id, "chickpea-curry")
    XCTAssertEqual(payload.results.first?.ingredients.first?.state, .pantryAndOffer)

    try await application.asyncShutdown()
  }
}
