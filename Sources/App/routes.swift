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

  let authController = AdminAuthController()
  app.get("admin", "login", use: authController.loginPage)
  app.grouped(AdminErrorMiddleware()).post("admin", "login", use: authController.login)

  let adminController = AdminController()
  let admin = app.grouped("admin").grouped(AdminErrorMiddleware(), AdminGuardMiddleware())
  admin.get(use: adminController.dashboard)
  admin.post("logout", use: authController.logout)
  admin.get("contact-information", use: adminController.contactInformation)
  admin.post("contact-information", use: adminController.updateContactInformation)

  admin.get("ingredients", use: adminController.ingredients)
  admin.get("ingredients", "new", use: adminController.newIngredient)
  admin.post("ingredients", use: adminController.createIngredient)
  admin.get("ingredients", ":id", "edit", use: adminController.editIngredient)
  admin.post("ingredients", ":id", "update", use: adminController.updateIngredient)
  admin.post("ingredients", ":id", "delete", use: adminController.deleteIngredient)

  admin.get("supermarkets", use: adminController.supermarkets)
  admin.get("supermarkets", "new", use: adminController.newSupermarket)
  admin.post("supermarkets", use: adminController.createSupermarket)
  admin.get("supermarkets", ":id", "edit", use: adminController.editSupermarket)
  admin.post("supermarkets", ":id", "update", use: adminController.updateSupermarket)
  admin.post("supermarkets", ":id", "delete", use: adminController.deleteSupermarket)

  admin.get("recipe-sources", use: adminController.recipeSources)
  admin.get("recipe-sources", "new", use: adminController.newRecipeSource)
  admin.post("recipe-sources", use: adminController.createRecipeSource)
  admin.get("recipe-sources", ":id", "edit", use: adminController.editRecipeSource)
  admin.post("recipe-sources", ":id", "update", use: adminController.updateRecipeSource)
  admin.post("recipe-sources", ":id", "delete", use: adminController.deleteRecipeSource)

  admin.get("dietary-preferences", use: adminController.dietaryPreferences)
  admin.get("dietary-preferences", "new", use: adminController.newDietaryPreference)
  admin.post("dietary-preferences", use: adminController.createDietaryPreference)
  admin.get(
    "dietary-preferences", ":id", "edit", use: adminController.editDietaryPreference)
  admin.post(
    "dietary-preferences", ":id", "update", use: adminController.updateDietaryPreference)
  admin.post(
    "dietary-preferences", ":id", "delete", use: adminController.deleteDietaryPreference)

  admin.get("offers", use: adminController.offers)
  admin.get("offers", "new", use: adminController.newOffer)
  admin.post("offers", use: adminController.createOffer)
  admin.get("offers", ":id", "edit", use: adminController.editOffer)
  admin.post("offers", ":id", "update", use: adminController.updateOffer)
  admin.post("offers", ":id", "delete", use: adminController.deleteOffer)

  admin.get("recipes", use: adminController.recipes)
  admin.get("recipes", "new", use: adminController.newRecipe)
  admin.on(
    .POST, "recipes", body: .collect(maxSize: "6mb"), use: adminController.createRecipe)
  admin.get("recipes", ":id", "edit", use: adminController.editRecipe)
  admin.on(
    .POST, "recipes", ":id", "update", body: .collect(maxSize: "6mb"),
    use: adminController.updateRecipe)
  admin.post("recipes", ":id", "delete", use: adminController.deleteRecipe)

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
