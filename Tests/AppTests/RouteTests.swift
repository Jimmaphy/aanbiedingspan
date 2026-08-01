import XCTVapor
import XCTest

@testable import App

final class RouteTests: XCTestCase {
  func testPublicRoutesUseConfiguredCatalogRepository() async throws {
    let application = try await Application.make(.testing)
    try await configure(application)
    let catalog = Catalog(
      dietaryPreferences: [.init(id: "plant-based", name: "Plantaardig")],
      ingredients: [.init(id: "managed-bean", name: "Beheerde boon")],
      supermarkets: [.init(id: "managed-market", name: "Beheerde markt")],
      recipes: [
        .init(
          id: "managed-recipe", title: "Beheerd testrecept", summary: "Alleen uit beheer.",
          imagePath: "/images/recipe-placeholder.svg",
          sourceURL: "https://voorbeeld.nl/recept", sourceName: "Voorbeeldbron",
          durationMinutes: 10, dietaryPreferenceIDs: ["plant-based"],
          ingredients: [
            .init(ingredientID: "managed-bean", displayText: "Beheerde boon", weight: 1)
          ])
      ],
      offers: [.init(ingredientID: "managed-bean", supermarketID: "managed-market")])
    application.catalogRepository = StaticCatalogRepository(catalog: catalog)

    let homeResponse = try await application.sendRequest(.GET, "/") { _ in await Task.yield() }
    XCTAssertContains(homeResponse.body.string, "Beheerde boon")
    XCTAssertContains(homeResponse.body.string, "Beheerde markt")
    XCTAssertFalse(homeResponse.body.string.contains("Kikkererwten"))

    let searchResponse = try await application.sendRequest(
      .POST, "/search",
      beforeRequest: { request in
        request.headers.contentType = .urlEncodedForm
        request.body = .init(
          string: "pantryIngredients%5B%5D=managed-bean&supermarkets%5B%5D=managed-market")
        await Task.yield()
      })
    XCTAssertContains(searchResponse.body.string, "Beheerd testrecept")
    XCTAssertContains(searchResponse.body.string, "aria-label=\"100 procent match\"")

    let ingredientResponse = try await application.sendRequest(.GET, "/api/ingredients") { _ in
      await Task.yield()
    }
    let ingredientPayload = try ingredientResponse.content.decode(IngredientListResponse.self)
    XCTAssertEqual(ingredientPayload.ingredients.map(\.name), ["Beheerde boon"])

    try await application.asyncShutdown()
  }

  func testEmptyManagedCatalogShowsAnAccessibleExplanation() async throws {
    let application = try await Application.make(.testing)
    try await configure(application)
    application.catalogRepository = StaticCatalogRepository(
      catalog: Catalog(
        dietaryPreferences: [], ingredients: [], supermarkets: [], recipes: [], offers: []))

    let response = try await application.sendRequest(.GET, "/") { _ in await Task.yield() }
    XCTAssertEqual(response.status, .ok)
    XCTAssertContains(
      response.body.string,
      "Er staan nog niet genoeg keuzes klaar om te zoeken. Probeer het later opnieuw.")
    XCTAssertContains(response.body.string, "role=\"status\"")

    try await application.asyncShutdown()
  }

  func testPublicPagesRenderDutchContentAndSecurityHeaders() async throws {
    let application = try await Application.make(.testing)
    try await configure(application)

    let homeResponse = try await application.sendRequest(.GET, "/") { _ in await Task.yield() }
    XCTAssertEqual(homeResponse.status, .ok)
    XCTAssertContains(homeResponse.body.string, "Vind een recept met wat je al hebt")
    XCTAssertContains(homeResponse.body.string, "Welke wensen heb je?")
    XCTAssertContains(homeResponse.body.string, "data-submit>Toon recepten</button>")
    XCTAssertContains(homeResponse.body.string, "Onthoud mijn keuzes voor een volgend bezoek")
    XCTAssertEqual(
      homeResponse.body.string.components(separatedBy: "data-ingredient-picker").count, 3)
    XCTAssertContains(homeResponse.body.string, "Geselecteerd voor in huis")
    XCTAssertContains(homeResponse.body.string, "/css/app.css?v=2")
    XCTAssertContains(homeResponse.body.string, "/js/ingredient-picker.js?v=5")
    XCTAssertContains(homeResponse.body.string, "/js/app.js?v=2")
    XCTAssertFalse(homeResponse.body.string.contains("aria-label=\"Hoofdnavigatie\""))
    XCTAssertContains(homeResponse.body.string, "/images/aanbiedingspan-logo.svg")
    XCTAssertEqual(homeResponse.headers.first(name: .xFrameOptions), "DENY")

    let styleResponse = try await application.sendRequest(.GET, "/css/app.css") { _ in
      await Task.yield()
    }
    XCTAssertEqual(styleResponse.status, .ok)
    XCTAssertContains(styleResponse.body.string, "[hidden]")

    let placeholderAboutResponse = try await application.sendRequest(.GET, "/about") { _ in
      await Task.yield()
    }
    XCTAssertContains(
      placeholderAboutResponse.body.string,
      "De contactadressen worden voor de publieke proef bevestigd.")

    application.contactInformationRepository = StaticContactInformationRepository(
      contactEmail: "hallo@aanbiedingspan.nl")
    let aboutResponse = try await application.sendRequest(.GET, "/about") { _ in await Task.yield()
    }
    XCTAssertEqual(aboutResponse.status, .ok)
    XCTAssertContains(aboutResponse.body.string, "Zo komt je match tot stand")
    XCTAssertContains(aboutResponse.body.string, "De missie")
    XCTAssertContains(aboutResponse.body.string, "jimmaphy.nl")
    XCTAssertContains(aboutResponse.body.string, "mailto:hallo@aanbiedingspan.nl")

    let privacyResponse = try await application.sendRequest(.GET, "/privacy") { _ in
      await Task.yield()
    }
    XCTAssertEqual(privacyResponse.status, .ok)
    XCTAssertContains(privacyResponse.body.string, "Jouw keuzes blijven van jou")
    XCTAssertContains(
      privacyResponse.body.string,
      "Zonder vinkje werkt Aanbiedingspan gewoon. Bij je volgende bezoek vul je de wizard opnieuw in."
    )

    try await application.asyncShutdown()
  }

  func testRenderedSearchSummarizesIngredientsWithoutListingThem() async throws {
    let application = try await Application.make(.testing)
    try await configure(application)

    let response = try await application.sendRequest(
      .POST, "/search",
      beforeRequest: { requestMessage in
        requestMessage.headers.contentType = .urlEncodedForm
        requestMessage.body = .init(
          string:
            "pantryIngredients%5B%5D=chickpeas&pantryIngredients%5B%5D=coconut-milk&supermarkets%5B%5D=lidl"
        )
        await Task.yield()
      })

    XCTAssertEqual(response.status, .ok)
    XCTAssertContains(response.body.string, "5 ingrediënten")
    XCTAssertContains(response.body.string, "2 in huis")
    XCTAssertContains(response.body.string, "1 in de aanbieding")
    XCTAssertFalse(response.body.string.contains("ingredient-status-list"))
    XCTAssertContains(
      response.body.string,
      "Recepten openen in een nieuw tabblad, zodat je hier makkelijk verder zoekt.")
    XCTAssertFalse(response.body.string.contains("Bekijk bij Demobron (opent"))

    let body = response.body.string
    let preferencesIndex = try XCTUnwrap(body.range(of: "class=\"tag-list\"")?.lowerBound)
    let titleIndex = try XCTUnwrap(body.range(of: "Kikkererwtencurry met rijst")?.lowerBound)
    let detailsIndex = try XCTUnwrap(
      body.range(of: "<strong>35 minuten</strong>")?.lowerBound)
    let summaryIndex = try XCTUnwrap(
      body.range(of: "Een zachte curry met kokosmelk")?.lowerBound)
    XCTAssertLessThan(preferencesIndex, titleIndex)
    XCTAssertLessThan(titleIndex, detailsIndex)
    XCTAssertLessThan(detailsIndex, summaryIndex)

    try await application.asyncShutdown()
  }

  func testRecipeDetailsHTMLHighlightsCoreInformationAndOmitsZeroCounts() {
    XCTAssertEqual(
      RecipeCardContext.makeDetailsHTML(
        durationMinutes: 20, ingredientCount: 4, pantryCount: 0, offerCount: 0),
      "<strong>20 minuten</strong> werk met <strong>4 ingrediënten.</strong>"
    )
    XCTAssertEqual(
      RecipeCardContext.makeDetailsHTML(
        durationMinutes: 20, ingredientCount: 4, pantryCount: 0, offerCount: 2),
      "<strong>20 minuten</strong> werk met <strong>4 ingrediënten</strong>, waarvan <strong>2 in de aanbieding.</strong>"
    )
    XCTAssertEqual(
      RecipeCardContext.makeDetailsHTML(
        durationMinutes: 20, ingredientCount: 4, pantryCount: 3, offerCount: 0),
      "<strong>20 minuten</strong> werk met <strong>4 ingrediënten</strong>, waarvan <strong>3 in huis.</strong>"
    )
    XCTAssertEqual(
      RecipeCardContext.makeDetailsHTML(
        durationMinutes: 20, ingredientCount: 4, pantryCount: 3, offerCount: 2),
      "<strong>20 minuten</strong> werk met <strong>4 ingrediënten</strong>, waarvan <strong>3 in huis</strong> en <strong>2 in de aanbieding.</strong>"
    )
  }

  func testRenderedSearchAcceptsNoFilters() async throws {
    let application = try await Application.make(.testing)
    try await configure(application)

    let response = try await application.sendRequest(
      .POST, "/search",
      beforeRequest: { requestMessage in
        requestMessage.headers.contentType = .urlEncodedForm
        requestMessage.body = .init(string: "search=1")
        await Task.yield()
      })

    XCTAssertEqual(response.status, .ok)
    XCTAssertContains(response.body.string, "3 recepten gevonden")

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
