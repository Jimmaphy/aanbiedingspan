import Vapor

struct PageController {
  func home(request: Request) async throws -> View {
    let catalog = try await request.application.catalogRepository.load(on: request.db)
    let context = SearchPageContext(
      catalog: catalog,
      request: .empty,
      results: [],
      hasSearched: false
    )
    return try await request.view.render("search", context)
  }

  func search(request: Request) async throws -> View {
    let searchRequest = try request.content.decode(SearchRequest.self)
    let catalog = try await request.application.catalogRepository.load(on: request.db)
    let results: [RankedRecipe]

    do {
      results = try SearchService(catalog: catalog).search(filters: searchRequest.filters)
    } catch SearchError.conflictingIngredients {
      throw Abort(
        .badRequest,
        reason: "Een ingrediënt kan niet tegelijk in huis en uitgesloten zijn. Pas je keuze aan."
      )
    }

    let context = SearchPageContext(
      catalog: catalog,
      request: searchRequest,
      results: results,
      hasSearched: true
    )
    return try await request.view.render("search", context)
  }

  func about(request: Request) async throws -> View {
    let contactEmail = try await request.application.contactInformationRepository.email(
      on: request.db)
    return try await request.view.render(
      "about",
      InformationPageContext(pageTitle: "Over Aanbiedingspan", contactEmail: contactEmail)
    )
  }

  func privacy(request: Request) async throws -> View {
    try await request.view.render(
      "privacy",
      InformationPageContext(pageTitle: "Privacy bij Aanbiedingspan")
    )
  }
}
