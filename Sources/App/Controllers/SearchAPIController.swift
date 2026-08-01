import Vapor

struct SearchAPIController {
  func search(request: Request) async throws -> SearchResponse {
    let searchRequest = try request.content.decode(SearchRequest.self)
    let (_, results) = try await SearchRequestExecutor().execute(searchRequest, on: request)
    return SearchResponse(results: results)
  }

  func ingredients(request: Request) async throws -> IngredientListResponse {
    let ingredients = try await request.application.catalogRepository.ingredients(on: request.db)
    return IngredientListResponse(ingredients: ingredients)
  }

  func supermarkets(request: Request) async throws -> SupermarketListResponse {
    let supermarkets = try await request.application.catalogRepository.supermarkets(on: request.db)
    return SupermarketListResponse(supermarkets: supermarkets)
  }
}
