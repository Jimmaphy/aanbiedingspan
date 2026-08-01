import Vapor

struct SearchRequestExecutor {
  func execute(
    _ searchRequest: SearchRequest, on request: Request
  ) async throws -> (Catalog, [RankedRecipe]) {
    let catalog = try await request.application.catalogRepository.load(on: request.db)
    do {
      return (catalog, try SearchService(catalog: catalog).search(filters: searchRequest.filters))
    } catch SearchError.conflictingIngredients {
      throw Abort(
        .badRequest,
        reason: "Een ingrediënt kan niet tegelijk in huis en uitgesloten zijn. Pas je keuze aan."
      )
    }
  }
}
