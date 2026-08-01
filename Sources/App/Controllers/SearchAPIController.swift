import Vapor

struct SearchAPIController {
  func search(request: Request) async throws -> SearchResponse {
    let searchRequest = try request.content.decode(SearchRequest.self)
    let catalog = try await request.application.catalogRepository.load(on: request.db)
    let results = try SearchService(catalog: catalog)
      .search(filters: searchRequest.filters)
    return SearchResponse(results: results)
  }

  func ingredients(request: Request) async throws -> IngredientListResponse {
    let catalog = try await request.application.catalogRepository.load(on: request.db)
    return IngredientListResponse(ingredients: catalog.ingredients)
  }

  func supermarkets(request: Request) async throws -> SupermarketListResponse {
    let catalog = try await request.application.catalogRepository.load(on: request.db)
    return SupermarketListResponse(supermarkets: catalog.supermarkets)
  }
}
