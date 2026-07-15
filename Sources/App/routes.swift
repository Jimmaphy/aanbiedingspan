import Fluent
import Vapor

func routes(_ app: Application) throws {
  let pageController = PageController()
  let apiController = SearchAPIController()

  app.get(use: pageController.home)
  app.post("search", use: pageController.search)
  app.get("about", use: pageController.about)
  app.get("privacy", use: pageController.privacy)

  app.post("api", "search", use: apiController.search)
  app.get("api", "ingredients", use: apiController.ingredients)
  app.get("api", "supermarkets", use: apiController.supermarkets)

  app.get("health", "live") { _ in
    HealthResponse(status: "ok")
  }
  app.get("health", "ready") { request async throws in
    try await request.db.transaction { database in
      database.eventLoop.makeSucceededFuture(())
    }.get()
    return HealthResponse(status: "ready")
  }
}

private struct HealthResponse: Content {
  let status: String
}
