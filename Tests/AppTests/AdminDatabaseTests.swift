import Fluent
import Foundation
import XCTVapor
import XCTest

@testable import App

final class AdminDatabaseTests: XCTestCase {
  func testCatalogRelationsAuditAndSoftDeleteAgainstPostgreSQL() async throws {
    guard ProcessInfo.processInfo.environment["RUN_POSTGRES_TESTS"] == "1" else {
      throw XCTSkip("Zet RUN_POSTGRES_TESTS=1 voor de PostgreSQL-integratietest.")
    }

    let application = try await Application.make(.testing)
    addTeardownBlock { try await application.asyncShutdown() }
    try await configure(application)
    application.adminAuth = .init(
      username: "testbeheerder", passwordHash: try Bcrypt.hash("testwachtwoord", cost: 4),
      role: "editor")
    try await CreateAdminCatalog().prepare(on: application.db)

    let legacyIngredient = ManagedIngredient(name: "Bestaand ingrediënt")
    let legacySupermarket = ManagedSupermarket(name: "Bestaande supermarkt")
    try await legacyIngredient.save(on: application.db)
    try await legacySupermarket.save(on: application.db)
    let legacyOffer = CreateOfferIngredients.LegacyOffer(
      ingredientID: try legacyIngredient.requireID(),
      supermarketID: try legacySupermarket.requireID(), validFrom: Date(),
      validUntil: Date().addingTimeInterval(86_400))
    try await legacyOffer.save(on: application.db)

    try await CreateOfferIngredients().prepare(on: application.db)
    let backfilledLinks = try await ManagedOfferIngredient.query(on: application.db)
      .filter(\.$offer.$id == legacyOffer.requireID()).all()
    XCTAssertEqual(backfilledLinks.map(\.$ingredient.id), [try legacyIngredient.requireID()])
    try await AddRecipeMediaAndPreferences().prepare(on: application.db)
    try await AddPublishingStatus().prepare(on: application.db)
    try await CreateContactInformation().prepare(on: application.db)
    let queriedDietaryPreference = try await ManagedDietaryPreference.query(on: application.db)
      .filter(\.$slug == "vegetarian").first()
    let dietaryPreference = try XCTUnwrap(queriedDietaryPreference)

    let suffix = UUID().uuidString
    let session = try await login(to: application)
    try await post(
      "/admin/ingredients", body: "name=Testingredient-\(suffix)", session: session,
      to: application)
    try await post(
      "/admin/ingredients", body: "name=Tweede-testingredient-\(suffix)", session: session,
      to: application)
    try await post(
      "/admin/supermarkets", body: "name=Testsupermarkt-\(suffix)", session: session,
      to: application)
    try await post(
      "/admin/recipe-sources",
      body: "name=Testbron-\(suffix)&websiteURL=https%3A%2F%2Fvoorbeeld.nl", session: session,
      to: application)

    let queriedIngredient = try await ManagedIngredient.query(on: application.db)
      .filter(\.$name == "Testingredient-\(suffix)").first()
    let queriedSupermarket = try await ManagedSupermarket.query(on: application.db)
      .filter(\.$name == "Testsupermarkt-\(suffix)").first()
    let queriedSource = try await RecipeSourceRecord.query(on: application.db)
      .filter(\.$name == "Testbron-\(suffix)").first()
    let ingredient = try XCTUnwrap(queriedIngredient)
    let queriedSecondIngredient = try await ManagedIngredient.query(on: application.db)
      .filter(\.$name == "Tweede-testingredient-\(suffix)").first()
    let secondIngredient = try XCTUnwrap(queriedSecondIngredient)
    let supermarket = try XCTUnwrap(queriedSupermarket)
    let source = try XCTUnwrap(queriedSource)

    let activeFrom = AdminValidation.dateString(Date().addingTimeInterval(-86_400))
    let activeUntil = AdminValidation.dateString(Date().addingTimeInterval(86_400))
    try await post(
      "/admin/offers",
      body:
        "ingredientIDs%5B%5D=\(try ingredient.requireID())&ingredientIDs%5B%5D=\(try secondIngredient.requireID())&supermarketID=\(try supermarket.requireID())&validFrom=\(activeFrom)&validUntil=\(activeUntil)&isPublished=on",
      session: session, to: application)
    try await post(
      "/admin/recipes",
      body:
        "title=Testrecept-\(suffix)&summary=Een%20recept%20voor%20de%20databasetest.&sourceURL=https%3A%2F%2Fvoorbeeld.nl%2Frecept&durationMinutes=20&sourceID=\(try source.requireID())&ingredientIDs%5B%5D=\(try ingredient.requireID())&dietaryPreferenceIDs%5B%5D=\(try dietaryPreference.requireID())&isPublished=on",
      session: session, to: application)

    let queriedCreatedRecipe = try await ManagedRecipe.query(on: application.db)
      .filter(\.$title == "Testrecept-\(suffix)").first()
    let recipe = try XCTUnwrap(queriedCreatedRecipe)

    let queriedRecipe = try await ManagedRecipe.query(on: application.db)
      .filter(\.$id == recipe.requireID()).with(\.$source).with(\.$ingredients)
      .with(\.$dietaryPreferences).first()
    let loadedRecipe = try XCTUnwrap(queriedRecipe)
    XCTAssertEqual(loadedRecipe.source.name, source.name)
    XCTAssertEqual(loadedRecipe.ingredients.map(\.name), [ingredient.name])
    XCTAssertEqual(loadedRecipe.dietaryPreferences.map(\.slug), ["vegetarian"])
    XCTAssertTrue(loadedRecipe.isPublished)
    let offerCount = try await ManagedOffer.query(on: application.db).count()
    let queriedOffer = try await ManagedOffer.query(on: application.db)
      .filter(\.$supermarket.$id == supermarket.requireID()).with(\.$ingredients).first()
    let loadedOffer = try XCTUnwrap(queriedOffer)
    let auditCount = try await AdminAuditEntry.query(on: application.db).count()
    XCTAssertEqual(offerCount, 2)
    XCTAssertEqual(
      Set(loadedOffer.ingredients.map(\.name)), Set([ingredient.name, secondIngredient.name]))
    XCTAssertTrue(loadedOffer.isPublished)
    XCTAssertEqual(auditCount, 6)

    let draftRecipe = ManagedRecipe(
      title: "Conceptrecept-\(suffix)", summary: "Dit recept mag niet openbaar zijn.",
      sourceURL: "https://voorbeeld.nl/concept", durationMinutes: 15,
      sourceID: try source.requireID())
    try await draftRecipe.save(on: application.db)
    try await ManagedRecipeIngredient(
      recipeID: try draftRecipe.requireID(), ingredientID: try secondIngredient.requireID()
    ).save(on: application.db)

    application.catalogRepository = ManagedCatalogRepository()
    let publicCatalog = try await application.catalogRepository.load(on: application.db)
    XCTAssertEqual(publicCatalog.recipes.map(\.title), [recipe.title])
    XCTAssertEqual(publicCatalog.offers.count, 2)
    XCTAssertEqual(Set(publicCatalog.offers.map(\.ingredientID)).count, 2)

    let publicSearch = try await application.sendRequest(
      .POST, "/search",
      beforeRequest: { request in
        request.headers.contentType = .urlEncodedForm
        request.body = .init(string: "supermarkets%5B%5D=\(try supermarket.requireID())")
        await Task.yield()
      })
    XCTAssertContains(publicSearch.body.string, recipe.title)
    XCTAssertFalse(publicSearch.body.string.contains(draftRecipe.title))

    let offerPage = try await get("/admin/offers", session: session, from: application)
    XCTAssertEqual(offerPage.status, .ok)
    XCTAssertContains(offerPage.body.string, ingredient.name)
    XCTAssertContains(offerPage.body.string, secondIngredient.name)
    XCTAssertContains(offerPage.body.string, supermarket.name)
    XCTAssertFalse(offerPage.body.string.contains("€"))
    let offerForm = try await get("/admin/offers/new", session: session, from: application)
    XCTAssertContains(offerForm.body.string, "Zoek een ingrediënt")
    XCTAssertContains(offerForm.body.string, "ingredientIDs[]")
    XCTAssertFalse(offerForm.body.string.contains("Prijs"))

    try await post(
      "/admin/offers/\(try loadedOffer.requireID())/update",
      body:
        "ingredientIDs%5B%5D=\(try secondIngredient.requireID())&supermarketID=\(try supermarket.requireID())&validFrom=2026-08-01&validUntil=2026-08-03",
      session: session, to: application)
    let queriedUpdatedOffer = try await ManagedOffer.query(on: application.db)
      .filter(\.$id == loadedOffer.requireID()).with(\.$ingredients).first()
    let updatedOffer = try XCTUnwrap(queriedUpdatedOffer)
    XCTAssertEqual(updatedOffer.ingredients.map(\.name), [secondIngredient.name])
    XCTAssertEqual(AdminValidation.dateString(updatedOffer.validFrom), "2026-08-01")
    XCTAssertEqual(AdminValidation.dateString(updatedOffer.validUntil), "2026-08-03")
    let updatedAuditCount = try await AdminAuditEntry.query(on: application.db).count()
    XCTAssertEqual(updatedAuditCount, 7)

    let recipeForm = try await get("/admin/recipes/new", session: session, from: application)
    XCTAssertEqual(recipeForm.status, .ok)
    XCTAssertContains(recipeForm.body.string, "Hoeveelheden en maten zijn niet nodig")
    XCTAssertContains(recipeForm.body.string, "Nieuw ingrediënt")
    XCTAssertContains(recipeForm.body.string, "Nieuwe receptbron")
    XCTAssertContains(recipeForm.body.string, "Nieuwe gerechtswens")
    XCTAssertContains(recipeForm.body.string, "type=\"file\"")
    XCTAssertContains(recipeForm.body.string, "dietaryPreferenceIDs[]")
    XCTAssertContains(recipeForm.body.string, "data-ingredient-picker")
    XCTAssertContains(recipeForm.body.string, "Publiceer dit recept")
    XCTAssertFalse(recipeForm.body.string.contains("name=\"isPublished\" checked"))

    let contactForm = try await get(
      "/admin/contact-information", session: session, from: application)
    XCTAssertEqual(contactForm.status, .ok)
    XCTAssertContains(contactForm.body.string, "Openbaar e-mailadres")
    XCTAssertFalse(contactForm.body.string.contains("value=\"contact@aanbiedingspan.nl\""))

    let rejectedContactUpdate = try await application.sendRequest(
      .POST, "/admin/contact-information",
      beforeRequest: { request in
        request.headers.contentType = .urlEncodedForm
        request.headers.replaceOrAdd(name: .cookie, value: session.cookie)
        request.body = .init(string: "email=hallo%40aanbiedingspan.nl")
        await Task.yield()
      })
    XCTAssertEqual(rejectedContactUpdate.status, .forbidden)

    try await post(
      "/admin/contact-information", body: "email=hallo%40aanbiedingspan.nl",
      session: session, to: application)
    let contactRecord = try await ManagedContactInformation.find(
      ManagedContactInformation.singletonID, on: application.db)
    XCTAssertEqual(contactRecord?.email, "hallo@aanbiedingspan.nl")
    application.contactInformationRepository = ManagedContactInformationRepository()
    let managedAbout = try await application.sendRequest(.GET, "/about") { _ in await Task.yield() }
    XCTAssertContains(managedAbout.body.string, "mailto:hallo@aanbiedingspan.nl")

    let inlineIngredientName = "Inline-testingredient-\(suffix)"
    let inlineResponse = try await application.sendRequest(
      .POST, "/admin/ingredients",
      beforeRequest: { request in
        request.headers.contentType = .urlEncodedForm
        request.headers.replaceOrAdd(name: .accept, value: "application/json")
        request.headers.replaceOrAdd(name: .cookie, value: session.cookie)
        request.body = .init(
          string: "name=\(inlineIngredientName)&csrfToken=\(session.csrf)")
        await Task.yield()
      })
    XCTAssertEqual(inlineResponse.status, HTTPResponseStatus.created)
    XCTAssertContains(inlineResponse.body.string, inlineIngredientName)
    XCTAssertContains(inlineResponse.body.string, "ingredient")

    let inlinePreferenceName = "Seizoensgebonden-\(suffix)"
    let inlinePreferenceResponse = try await application.sendRequest(
      .POST, "/admin/dietary-preferences",
      beforeRequest: { request in
        request.headers.contentType = .urlEncodedForm
        request.headers.replaceOrAdd(name: .accept, value: "application/json")
        request.headers.replaceOrAdd(name: .cookie, value: session.cookie)
        request.body = .init(
          string: "name=\(inlinePreferenceName)&csrfToken=\(session.csrf)")
        await Task.yield()
      })
    XCTAssertEqual(inlinePreferenceResponse.status, HTTPResponseStatus.created)
    XCTAssertContains(inlinePreferenceResponse.body.string, inlinePreferenceName)
    XCTAssertContains(inlinePreferenceResponse.body.string, "dietaryPreference")

    let searchPage = try await get(
      "/admin/ingredients?q=Tweede-testingredient", session: session, from: application)
    XCTAssertContains(searchPage.body.string, secondIngredient.name)
    XCTAssertFalse(searchPage.body.string.contains(">\(ingredient.name)<"))

    try await post(
      "/admin/ingredients/\(try ingredient.requireID())/delete", body: "", session: session,
      to: application)
    let activeIngredient = try await ManagedIngredient.find(
      ingredient.requireID(), on: application.db)
    let deletedIngredient = try await ManagedIngredient.query(on: application.db).withDeleted()
      .filter(\.$id == ingredient.requireID()).first()
    XCTAssertNil(activeIngredient)
    XCTAssertNotNil(deletedIngredient)

    try await CreateContactInformation().revert(on: application.db)
    try await AddPublishingStatus().revert(on: application.db)
    try await AddRecipeMediaAndPreferences().revert(on: application.db)
    try await CreateOfferIngredients().revert(on: application.db)
    try await CreateAdminCatalog().revert(on: application.db)
  }

  private func login(to application: Application) async throws -> (cookie: String, csrf: String) {
    let page = try await application.sendRequest(.GET, "/admin/login") { _ in await Task.yield() }
    let token = try XCTUnwrap(value(of: "csrfToken", in: page.body.string))
    let cookie = try XCTUnwrap(page.headers.first(name: .setCookie))
      .split(separator: ";", maxSplits: 1).first.map(String.init)!
    let response = try await application.sendRequest(
      .POST, "/admin/login",
      beforeRequest: { request in
        request.headers.contentType = .urlEncodedForm
        request.headers.replaceOrAdd(name: .cookie, value: cookie)
        request.body = .init(
          string: "username=testbeheerder&password=testwachtwoord&csrfToken=\(token)")
        await Task.yield()
      })
    XCTAssertEqual(response.status, .seeOther)
    let authenticatedCookie = try XCTUnwrap(response.headers.first(name: .setCookie))
      .split(separator: ";", maxSplits: 1).first.map(String.init)!
    let dashboard = try await get("/admin", session: (authenticatedCookie, ""), from: application)
    return (authenticatedCookie, try XCTUnwrap(value(of: "csrfToken", in: dashboard.body.string)))
  }

  private func post(
    _ path: String, body: String, session: (cookie: String, csrf: String),
    to application: Application
  ) async throws {
    let separator = body.isEmpty ? "" : "&"
    let response = try await application.sendRequest(
      .POST, path,
      beforeRequest: { request in
        request.headers.contentType = .urlEncodedForm
        request.headers.replaceOrAdd(name: .cookie, value: session.cookie)
        request.body = .init(string: "\(body)\(separator)csrfToken=\(session.csrf)")
        await Task.yield()
      })
    XCTAssertEqual(response.status, .seeOther, "POST \(path): \(response.body.string)")
  }

  private func get(
    _ path: String, session: (cookie: String, csrf: String), from application: Application
  ) async throws -> XCTHTTPResponse {
    try await application.sendRequest(
      .GET, path,
      beforeRequest: { request in
        request.headers.replaceOrAdd(name: .cookie, value: session.cookie)
        await Task.yield()
      })
  }

  private func value(of inputName: String, in html: String) -> String? {
    let marker = "name=\"\(inputName)\" value=\""
    guard let start = html.range(of: marker)?.upperBound,
      let end = html[start...].firstIndex(of: "\"")
    else { return nil }
    return String(html[start..<end])
  }
}
