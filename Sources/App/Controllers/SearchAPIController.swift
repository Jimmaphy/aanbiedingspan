import Vapor

struct SearchAPIController {
  func search(request: Request) async throws -> SearchResponse {
    let searchRequest = try request.content.decode(SearchRequest.self)
    let results = try SearchService(catalog: request.application.catalog)
      .search(filters: searchRequest.filters)
    return SearchResponse(results: results)
  }

  func ingredients(request: Request) -> IngredientListResponse {
    IngredientListResponse(ingredients: request.application.catalog.ingredients)
  }

  func supermarkets(request: Request) -> SupermarketListResponse {
    SupermarketListResponse(supermarkets: request.application.catalog.supermarkets)
  }
}
