import Fluent
import Foundation
import Vapor

private struct SimpleRecordForm: Content {
  let name: String
  let websiteURL: String?
  let returnTo: String?
  let csrfToken: String?
}

private struct ContactInformationForm: Content {
  let email: String
  let csrfToken: String?
}

private struct OfferForm: Content {
  let ingredientIDs: [String]?
  let supermarketID: String
  let validFrom: String
  let validUntil: String
  let isPublished: String?
  let csrfToken: String?
}

private struct ValidatedOffer {
  let supermarketID: UUID
  let ingredientIDs: [UUID]
  let validFrom: Date
  let validUntil: Date
}

private struct QuickCreateResponse: Content {
  let id: String
  let name: String
  let kind: String
}

private struct RecipeForm: Content {
  let title: String
  let summary: String
  let sourceURL: String
  let durationMinutes: String
  let sourceID: String
  let ingredientIDs: [String]?
  let dietaryPreferenceIDs: [String]?
  let image: File?
  let isPublished: String?
  let csrfToken: String?
}

private struct ValidatedRecipe {
  let title: String
  let summary: String
  let url: String
  let duration: Int
  let sourceID: UUID
  let ingredientIDs: [UUID]
  let dietaryPreferenceIDs: [UUID]
}

struct AdminController {
  func dashboard(request: Request) async throws -> View {
    let identity = try identity(request)
    return try await request.view.render(
      "admin/dashboard",
      AdminShellContext(
        pageTitle: "Beheer", heading: "Administratieportaal",
        introduction: "Beheer hier de gegevens waarmee Aanbiedingspan werkt.",
        username: identity.username, csrfToken: AdminSession.csrfToken(for: request)))
  }

  func contactInformation(request: Request) async throws -> View {
    let record = try await ManagedContactInformation.find(
      ManagedContactInformation.singletonID, on: request.db)
    return try await request.view.render(
      "admin/contact-information",
      AdminContactInformationContext(
        username: try identity(request).username,
        csrfToken: AdminSession.csrfToken(for: request),
        email: record?.email ?? ""))
  }

  func updateContactInformation(request: Request) async throws -> Response {
    let form = try request.content.decode(ContactInformationForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let email = try AdminValidation.email(form.email)
    let actor = try identity(request).username

    try await request.db.transaction { database in
      if let record = try await ManagedContactInformation.find(
        ManagedContactInformation.singletonID, on: database)
      {
        record.email = email
        try await record.update(on: database)
        try await AdminAuditEntry(
          actor: actor, action: "update", entityType: "contact_information",
          entityID: ManagedContactInformation.singletonID
        ).save(on: database)
      } else {
        let record = ManagedContactInformation(email: email)
        try await record.save(on: database)
        try await AdminAuditEntry(
          actor: actor, action: "create", entityType: "contact_information",
          entityID: ManagedContactInformation.singletonID
        ).save(on: database)
      }
    }
    return request.redirect(to: "/admin/contact-information")
  }

  // MARK: Ingredients

  func ingredients(request: Request) async throws -> View {
    let page = pageNumber(request)
    let search = searchTerm(request)
    let query = ManagedIngredient.query(on: request.db).sort(\.$name)
    if !search.isEmpty { query.filter(\.$name, .custom("ilike"), "%\(search)%") }
    let records =
      try await query
      .offset((page - 1) * 50).limit(51).all()
    return try await renderList(
      request, title: "Ingrediënten", introduction: "Beheer de vaste namen van ingrediënten.",
      basePath: "/admin/ingredients", createLabel: "Nieuw ingrediënt",
      searchTerm: search,
      emptyMessage: "Er zijn nog geen ingrediënten.",
      items: try records.map {
        .init(id: try $0.requireID().uuidString, title: $0.name, detail: "")
      })
  }

  func newIngredient(request: Request) async throws -> View {
    try await renderSimpleForm(
      request, heading: "Ingrediënt toevoegen", action: "/admin/ingredients",
      cancelPath: "/admin/ingredients", name: "", websiteURL: "", showsURL: false)
  }

  func createIngredient(request: Request) async throws -> Response {
    let form = try request.content.decode(SimpleRecordForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let name = try AdminValidation.text(form.name, field: "de naam")
    guard try await ManagedIngredient.query(on: request.db).filter(\.$name == name).first() == nil
    else {
      throw Abort(.unprocessableEntity, reason: "Dit ingrediënt bestaat al.")
    }
    let record = ManagedIngredient(name: name)
    try await saveAndAudit(record, entity: "ingredient", request: request)
    if request.headers.accept.contains(where: { $0.mediaType == .json }) {
      return try await QuickCreateResponse(
        id: try record.requireID().uuidString, name: record.name, kind: "ingredient"
      ).encodeResponse(status: .created, for: request)
    }
    return request.redirect(to: safeReturn(form.returnTo, fallback: "/admin/ingredients"))
  }

  func editIngredient(request: Request) async throws -> View {
    let record = try await find(ManagedIngredient.self, request)
    return try await renderSimpleForm(
      request, heading: "Ingrediënt wijzigen",
      action: "/admin/ingredients/\(try record.requireID())/update",
      cancelPath: "/admin/ingredients",
      name: record.name, websiteURL: "", showsURL: false)
  }

  func updateIngredient(request: Request) async throws -> Response {
    let form = try request.content.decode(SimpleRecordForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let record = try await find(ManagedIngredient.self, request)
    record.name = try AdminValidation.text(form.name, field: "de naam")
    try await updateAndAudit(record, entity: "ingredient", request: request)
    return request.redirect(to: "/admin/ingredients")
  }

  func deleteIngredient(request: Request) async throws -> Response {
    try await delete(ManagedIngredient.self, entity: "ingredient", request: request)
  }

  // MARK: Supermarkets

  func supermarkets(request: Request) async throws -> View {
    let page = pageNumber(request)
    let search = searchTerm(request)
    let query = ManagedSupermarket.query(on: request.db).sort(\.$name)
    if !search.isEmpty { query.filter(\.$name, .custom("ilike"), "%\(search)%") }
    let records =
      try await query
      .offset((page - 1) * 50).limit(51).all()
    return try await renderList(
      request, title: "Supermarkten",
      introduction: "Beheer supermarktketens. We bewaren geen filialen of locaties.",
      basePath: "/admin/supermarkets", createLabel: "Nieuwe supermarkt",
      searchTerm: search,
      emptyMessage: "Er zijn nog geen supermarkten.",
      items: try records.map {
        .init(id: try $0.requireID().uuidString, title: $0.name, detail: "")
      })
  }

  func newSupermarket(request: Request) async throws -> View {
    try await renderSimpleForm(
      request, heading: "Supermarkt toevoegen", action: "/admin/supermarkets",
      cancelPath: "/admin/supermarkets", name: "", websiteURL: "", showsURL: false)
  }

  func createSupermarket(request: Request) async throws -> Response {
    let form = try request.content.decode(SimpleRecordForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let name = try AdminValidation.text(form.name, field: "de naam")
    guard try await ManagedSupermarket.query(on: request.db).filter(\.$name == name).first() == nil
    else {
      throw Abort(.unprocessableEntity, reason: "Deze supermarkt bestaat al.")
    }
    let supermarket = ManagedSupermarket(name: name)
    try await saveAndAudit(supermarket, entity: "supermarket", request: request)
    if request.headers.accept.contains(where: { $0.mediaType == .json }) {
      return try await QuickCreateResponse(
        id: try supermarket.requireID().uuidString, name: supermarket.name, kind: "supermarket"
      ).encodeResponse(status: .created, for: request)
    }
    return request.redirect(to: safeReturn(form.returnTo, fallback: "/admin/supermarkets"))
  }

  func editSupermarket(request: Request) async throws -> View {
    let record = try await find(ManagedSupermarket.self, request)
    return try await renderSimpleForm(
      request, heading: "Supermarkt wijzigen",
      action: "/admin/supermarkets/\(try record.requireID())/update",
      cancelPath: "/admin/supermarkets",
      name: record.name, websiteURL: "", showsURL: false)
  }

  func updateSupermarket(request: Request) async throws -> Response {
    let form = try request.content.decode(SimpleRecordForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let record = try await find(ManagedSupermarket.self, request)
    record.name = try AdminValidation.text(form.name, field: "de naam")
    try await updateAndAudit(record, entity: "supermarket", request: request)
    return request.redirect(to: "/admin/supermarkets")
  }

  func deleteSupermarket(request: Request) async throws -> Response {
    try await delete(ManagedSupermarket.self, entity: "supermarket", request: request)
  }

  // MARK: Recipe sources

  func recipeSources(request: Request) async throws -> View {
    let page = pageNumber(request)
    let search = searchTerm(request)
    let query = RecipeSourceRecord.query(on: request.db).sort(\.$name)
    if !search.isEmpty { query.filter(\.$name, .custom("ilike"), "%\(search)%") }
    let records =
      try await query
      .offset((page - 1) * 50).limit(51).all()
    return try await renderList(
      request, title: "Receptbronnen",
      introduction: "Beheer de websites waar handmatig ingevoerde recepten vandaan komen.",
      basePath: "/admin/recipe-sources", createLabel: "Nieuwe receptbron",
      searchTerm: search,
      emptyMessage: "Er zijn nog geen receptbronnen.",
      items: try records.map {
        .init(
          id: try $0.requireID().uuidString, title: $0.name,
          detail: $0.websiteURL ?? "Geen websiteadres")
      })
  }

  func newRecipeSource(request: Request) async throws -> View {
    try await renderSimpleForm(
      request, heading: "Receptbron toevoegen", action: "/admin/recipe-sources",
      cancelPath: "/admin/recipe-sources", name: "", websiteURL: "", showsURL: true)
  }

  func createRecipeSource(request: Request) async throws -> Response {
    let form = try request.content.decode(SimpleRecordForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let name = try AdminValidation.text(form.name, field: "de naam")
    guard try await RecipeSourceRecord.query(on: request.db).filter(\.$name == name).first() == nil
    else {
      throw Abort(.unprocessableEntity, reason: "Deze receptbron bestaat al.")
    }
    let source = RecipeSourceRecord(
      name: name, websiteURL: try AdminValidation.optionalWebURL(form.websiteURL ?? ""))
    try await saveAndAudit(source, entity: "recipe_source", request: request)
    if request.headers.accept.contains(where: { $0.mediaType == .json }) {
      return try await QuickCreateResponse(
        id: try source.requireID().uuidString, name: source.name, kind: "recipeSource"
      ).encodeResponse(status: .created, for: request)
    }
    return request.redirect(to: safeReturn(form.returnTo, fallback: "/admin/recipe-sources"))
  }

  func editRecipeSource(request: Request) async throws -> View {
    let record = try await find(RecipeSourceRecord.self, request)
    return try await renderSimpleForm(
      request, heading: "Receptbron wijzigen",
      action: "/admin/recipe-sources/\(try record.requireID())/update",
      cancelPath: "/admin/recipe-sources",
      name: record.name, websiteURL: record.websiteURL ?? "", showsURL: true)
  }

  func updateRecipeSource(request: Request) async throws -> Response {
    let form = try request.content.decode(SimpleRecordForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let record = try await find(RecipeSourceRecord.self, request)
    record.name = try AdminValidation.text(form.name, field: "de naam")
    record.websiteURL = try AdminValidation.optionalWebURL(form.websiteURL ?? "")
    try await updateAndAudit(record, entity: "recipe_source", request: request)
    return request.redirect(to: "/admin/recipe-sources")
  }

  func deleteRecipeSource(request: Request) async throws -> Response {
    try await delete(RecipeSourceRecord.self, entity: "recipe_source", request: request)
  }

  // MARK: Dietary preferences

  func dietaryPreferences(request: Request) async throws -> View {
    let page = pageNumber(request)
    let search = searchTerm(request)
    let query = ManagedDietaryPreference.query(on: request.db).sort(\.$name)
    if !search.isEmpty { query.filter(\.$name, .custom("ilike"), "%\(search)%") }
    let records = try await query.offset((page - 1) * 50).limit(51).all()
    return try await renderList(
      request, title: "Gerechtswensen",
      introduction: "Beheer de tags die bezoekers in stap 1 van de wizard kunnen kiezen.",
      basePath: "/admin/dietary-preferences", createLabel: "Nieuwe gerechtswens",
      searchTerm: search, emptyMessage: "Er zijn nog geen gerechtswensen.",
      items: try records.map {
        .init(id: try $0.requireID().uuidString, title: $0.name, detail: $0.slug)
      })
  }

  func newDietaryPreference(request: Request) async throws -> View {
    try await renderSimpleForm(
      request, heading: "Gerechtswens toevoegen", action: "/admin/dietary-preferences",
      cancelPath: "/admin/dietary-preferences", name: "", websiteURL: "", showsURL: false)
  }

  func createDietaryPreference(request: Request) async throws -> Response {
    let form = try request.content.decode(SimpleRecordForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let name = try AdminValidation.text(form.name, field: "de naam")
    let slug = preferenceSlug(name)
    guard !slug.isEmpty else {
      throw Abort(.unprocessableEntity, reason: "Gebruik letters of cijfers in de naam.")
    }
    guard
      try await ManagedDietaryPreference.query(on: request.db).filter(\.$slug == slug).first()
        == nil
    else { throw Abort(.unprocessableEntity, reason: "Deze gerechtswens bestaat al.") }
    let preference = ManagedDietaryPreference(name: name, slug: slug)
    try await saveAndAudit(preference, entity: "dietary_preference", request: request)
    if request.headers.accept.contains(where: { $0.mediaType == .json }) {
      return try await QuickCreateResponse(
        id: try preference.requireID().uuidString, name: preference.name,
        kind: "dietaryPreference"
      ).encodeResponse(status: .created, for: request)
    }
    return request.redirect(
      to: safeReturn(form.returnTo, fallback: "/admin/dietary-preferences"))
  }

  func editDietaryPreference(request: Request) async throws -> View {
    let record = try await find(ManagedDietaryPreference.self, request)
    return try await renderSimpleForm(
      request, heading: "Gerechtswens wijzigen",
      action: "/admin/dietary-preferences/\(try record.requireID())/update",
      cancelPath: "/admin/dietary-preferences", name: record.name, websiteURL: "",
      showsURL: false)
  }

  func updateDietaryPreference(request: Request) async throws -> Response {
    let form = try request.content.decode(SimpleRecordForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let record = try await find(ManagedDietaryPreference.self, request)
    record.name = try AdminValidation.text(form.name, field: "de naam")
    record.slug = preferenceSlug(record.name)
    guard !record.slug.isEmpty else {
      throw Abort(.unprocessableEntity, reason: "Gebruik letters of cijfers in de naam.")
    }
    let duplicate = try await ManagedDietaryPreference.query(on: request.db)
      .filter(\.$slug == record.slug).all()
      .contains { $0.id != record.id }
    guard !duplicate else {
      throw Abort(.unprocessableEntity, reason: "Deze gerechtswens bestaat al.")
    }
    try await updateAndAudit(record, entity: "dietary_preference", request: request)
    return request.redirect(to: "/admin/dietary-preferences")
  }

  func deleteDietaryPreference(request: Request) async throws -> Response {
    try await delete(
      ManagedDietaryPreference.self, entity: "dietary_preference", request: request)
  }

  // MARK: Offers

  func offers(request: Request) async throws -> View {
    let page = pageNumber(request)
    let search = searchTerm(request)
    let loadedRecords = try await ManagedOffer.query(on: request.db)
      .with(\.$ingredients).with(\.$supermarket).sort(\.$validUntil, .descending)
      .limit(501).all()
    let filteredRecords = loadedRecords.filter { offer in
      search.isEmpty
        || searchableText(
          [offer.supermarket.name] + offer.ingredients.map(\.name)
            + [
              AdminValidation.dateString(offer.validFrom),
              AdminValidation.dateString(offer.validUntil),
            ]
        ).contains(searchableText([search]))
    }
    let records = Array(filteredRecords.dropFirst((page - 1) * 50).prefix(51))
    let items = try records.map { offer in
      let names = offer.ingredients.map(\.name).sorted()
      let countLabel = names.count == 1 ? "1 ingrediënt" : "\(names.count) ingrediënten"
      let shownNames = names.prefix(5).joined(separator: ", ")
      let remaining = names.count > 5 ? " en \(names.count - 5) meer" : ""
      return AdminListItemContext(
        id: try offer.requireID().uuidString,
        title: "\(offer.supermarket.name) · \(countLabel)",
        detail:
          "\(offer.isPublished ? "Gepubliceerd" : "Concept") · \(AdminValidation.dateString(offer.validFrom)) tot en met \(AdminValidation.dateString(offer.validUntil)) · \(shownNames)\(remaining)"
      )
    }
    return try await renderList(
      request, title: "Aanbiedingen",
      introduction: "Beheer welke ingrediënten tijdelijk in de aanbieding zijn.",
      basePath: "/admin/offers", createLabel: "Nieuwe aanbieding",
      searchTerm: search, emptyMessage: "Er zijn nog geen aanbiedingen.", items: items)
  }

  func newOffer(request: Request) async throws -> View {
    try await renderOfferForm(request, offer: nil)
  }

  func createOffer(request: Request) async throws -> Response {
    let form = try request.content.decode(OfferForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let values = try await validateOffer(form, request: request)
    let offer = ManagedOffer(
      legacyIngredientID: values.ingredientIDs[0], supermarketID: values.supermarketID,
      validFrom: values.validFrom, validUntil: values.validUntil,
      isPublished: form.isPublished == "on")
    let actor = try identity(request).username
    try await request.db.transaction { database in
      try await offer.save(on: database)
      let offerID = try offer.requireID()
      try await values.ingredientIDs.map {
        ManagedOfferIngredient(offerID: offerID, ingredientID: $0)
      }.create(on: database)
      try await AdminAuditEntry(
        actor: actor, action: "create", entityType: "offer", entityID: offerID
      ).save(on: database)
    }
    return request.redirect(to: "/admin/offers")
  }

  func editOffer(request: Request) async throws -> View {
    let offer = try await find(ManagedOffer.self, request)
    try await offer.$ingredients.load(on: request.db)
    return try await renderOfferForm(request, offer: offer)
  }

  func updateOffer(request: Request) async throws -> Response {
    let form = try request.content.decode(OfferForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let offer = try await find(ManagedOffer.self, request)
    let values = try await validateOffer(form, request: request)
    offer.$legacyIngredient.id = values.ingredientIDs[0]
    offer.$supermarket.id = values.supermarketID
    offer.validFrom = values.validFrom
    offer.validUntil = values.validUntil
    offer.isPublished = form.isPublished == "on"
    let offerID = try offer.requireID()
    let actor = try identity(request).username
    try await request.db.transaction { database in
      try await offer.update(on: database)
      try await ManagedOfferIngredient.query(on: database).filter(\.$offer.$id == offerID).delete()
      try await values.ingredientIDs.map {
        ManagedOfferIngredient(offerID: offerID, ingredientID: $0)
      }.create(on: database)
      try await AdminAuditEntry(
        actor: actor, action: "update", entityType: "offer", entityID: offerID
      ).save(on: database)
    }
    return request.redirect(to: "/admin/offers")
  }

  func deleteOffer(request: Request) async throws -> Response {
    try await delete(ManagedOffer.self, entity: "offer", request: request)
  }

  // MARK: Recipes

  func recipes(request: Request) async throws -> View {
    let page = pageNumber(request)
    let search = searchTerm(request)
    let query = ManagedRecipe.query(on: request.db).with(\.$source).sort(\.$title)
    if !search.isEmpty { query.filter(\.$title, .custom("ilike"), "%\(search)%") }
    let records =
      try await query
      .offset((page - 1) * 50).limit(51).all()
    return try await renderList(
      request, title: "Recepten",
      introduction: "Beheer de receptgegevens en hun canonieke ingrediënten.",
      basePath: "/admin/recipes", createLabel: "Nieuw recept",
      searchTerm: search, emptyMessage: "Er zijn nog geen recepten.",
      items: try records.map {
        .init(
          id: try $0.requireID().uuidString, title: $0.title,
          detail:
            "\($0.isPublished ? "Gepubliceerd" : "Concept") · \($0.durationMinutes) minuten · \($0.source.name)"
        )
      })
  }

  func newRecipe(request: Request) async throws -> View {
    try await renderRecipeForm(request, recipe: nil)
  }

  func createRecipe(request: Request) async throws -> Response {
    let form = try request.content.decode(RecipeForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let values = try await validateRecipe(form, request: request)
    let imagePath = try await RecipeImageStorage.save(form.image, for: request)
    let recipe = ManagedRecipe(
      title: values.title, summary: values.summary,
      sourceURL: values.url, durationMinutes: values.duration, sourceID: values.sourceID,
      imagePath: imagePath)
    recipe.isPublished = form.isPublished == "on"
    let actor = try identity(request).username
    do {
      try await request.db.transaction { database in
        try await recipe.save(on: database)
        let recipeID = try recipe.requireID()
        try await values.ingredientIDs.map {
          ManagedRecipeIngredient(recipeID: recipeID, ingredientID: $0)
        }.create(on: database)
        try await values.dietaryPreferenceIDs.map {
          ManagedRecipeDietaryPreference(recipeID: recipeID, preferenceID: $0)
        }.create(on: database)
        try await AdminAuditEntry(
          actor: actor, action: "create", entityType: "recipe", entityID: recipeID
        ).save(on: database)
      }
    } catch {
      RecipeImageStorage.remove(imagePath, for: request)
      throw error
    }
    return request.redirect(to: "/admin/recipes")
  }

  func editRecipe(request: Request) async throws -> View {
    let recipe = try await find(ManagedRecipe.self, request)
    try await recipe.$ingredients.load(on: request.db)
    try await recipe.$dietaryPreferences.load(on: request.db)
    return try await renderRecipeForm(request, recipe: recipe)
  }

  func updateRecipe(request: Request) async throws -> Response {
    let form = try request.content.decode(RecipeForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let recipe = try await find(ManagedRecipe.self, request)
    let values = try await validateRecipe(form, request: request)
    let replacementImagePath = try await RecipeImageStorage.save(form.image, for: request)
    let previousImagePath = recipe.imagePath
    recipe.title = values.title
    recipe.summary = values.summary
    recipe.sourceURL = values.url
    recipe.durationMinutes = values.duration
    recipe.isPublished = form.isPublished == "on"
    recipe.$source.id = values.sourceID
    if let replacementImagePath { recipe.imagePath = replacementImagePath }
    let recipeID = try recipe.requireID()
    let actor = try identity(request).username
    do {
      try await request.db.transaction { database in
        try await recipe.update(on: database)
        try await ManagedRecipeIngredient.query(on: database).filter(\.$recipe.$id == recipeID)
          .delete()
        try await values.ingredientIDs.map {
          ManagedRecipeIngredient(recipeID: recipeID, ingredientID: $0)
        }.create(on: database)
        try await ManagedRecipeDietaryPreference.query(on: database)
          .filter(\.$recipe.$id == recipeID).delete()
        try await values.dietaryPreferenceIDs.map {
          ManagedRecipeDietaryPreference(recipeID: recipeID, preferenceID: $0)
        }.create(on: database)
        try await AdminAuditEntry(
          actor: actor, action: "update", entityType: "recipe", entityID: recipeID
        ).save(on: database)
      }
    } catch {
      RecipeImageStorage.remove(replacementImagePath, for: request)
      throw error
    }
    if replacementImagePath != nil {
      RecipeImageStorage.remove(previousImagePath, for: request)
    }
    return request.redirect(to: "/admin/recipes")
  }

  func deleteRecipe(request: Request) async throws -> Response {
    try await delete(ManagedRecipe.self, entity: "recipe", request: request)
  }

  // MARK: Helpers

  private func renderList(
    _ request: Request, title: String, introduction: String,
    basePath: String, createLabel: String, searchTerm: String, emptyMessage: String,
    items: [AdminListItemContext]
  ) async throws -> View {
    let user = try identity(request)
    let page = pageNumber(request)
    let hasNext = items.count > 50
    return try await request.view.render(
      "admin/list",
      AdminListContext(
        pageTitle: title, heading: title, introduction: introduction, username: user.username,
        csrfToken: AdminSession.csrfToken(for: request), basePath: basePath,
        createLabel: createLabel, searchTerm: searchTerm,
        searchResultMessage: searchTerm.isEmpty
          ? nil : "Zoekresultaten voor ‘\(searchTerm)’.",
        emptyMessage: searchTerm.isEmpty ? emptyMessage : "Geen resultaten gevonden.",
        items: Array(items.prefix(50)),
        previousPath: page > 1 ? listPath(basePath, page: page - 1, search: searchTerm) : nil,
        nextPath: hasNext ? listPath(basePath, page: page + 1, search: searchTerm) : nil))
  }

  private func renderSimpleForm(
    _ request: Request, heading: String, action: String,
    cancelPath: String, name: String, websiteURL: String, showsURL: Bool
  ) async throws -> View {
    try await request.view.render(
      "admin/simple-form",
      AdminSimpleFormContext(
        pageTitle: heading, heading: heading, username: try identity(request).username,
        csrfToken: AdminSession.csrfToken(for: request), action: action, cancelPath: cancelPath,
        name: name, websiteURL: websiteURL, showsWebsiteURL: showsURL, errorMessage: nil))
  }

  private func renderOfferForm(_ request: Request, offer: ManagedOffer?) async throws -> View {
    let ingredients = try await ManagedIngredient.query(on: request.db).sort(\.$name).limit(500)
      .all()
    let supermarkets = try await ManagedSupermarket.query(on: request.db).sort(\.$name).limit(500)
      .all()
    let selectedIngredientIDs = Set(offer?.ingredients.compactMap(\.id) ?? [])
    let selectedSupermarket = offer?.$supermarket.id
    let action = try offer.map { "/admin/offers/\(try $0.requireID())/update" } ?? "/admin/offers"
    return try await request.view.render(
      "admin/offer-form",
      AdminOfferFormContext(
        pageTitle: offer == nil ? "Aanbieding toevoegen" : "Aanbieding wijzigen",
        heading: offer == nil ? "Aanbieding toevoegen" : "Aanbieding wijzigen",
        username: try identity(request).username, csrfToken: AdminSession.csrfToken(for: request),
        action: action, returnPath: request.url.path,
        ingredients: try ingredients.map {
          option(
            try $0.requireID(), $0.name, nil,
            selectedIngredientIDs.contains(try $0.requireID()))
        },
        supermarkets: try supermarkets.map {
          option(try $0.requireID(), $0.name, selectedSupermarket, false)
        },
        validFrom: offer.map { AdminValidation.dateString($0.validFrom) } ?? "",
        validUntil: offer.map { AdminValidation.dateString($0.validUntil) } ?? "",
        publishedCheckedAttribute: offer?.isPublished == true ? "checked" : "",
        errorMessage: nil
      ))
  }

  private func renderRecipeForm(_ request: Request, recipe: ManagedRecipe?) async throws -> View {
    let sources = try await RecipeSourceRecord.query(on: request.db).sort(\.$name).limit(500).all()
    let ingredients = try await ManagedIngredient.query(on: request.db).sort(\.$name).limit(500)
      .all()
    let preferences = try await ManagedDietaryPreference.query(on: request.db).sort(\.$name)
      .limit(100).all()
    let ingredientIDs = Set(recipe?.ingredients.compactMap(\.id) ?? [])
    let preferenceIDs = Set(recipe?.dietaryPreferences.compactMap(\.id) ?? [])
    let action =
      try recipe.map { "/admin/recipes/\(try $0.requireID())/update" } ?? "/admin/recipes"
    return try await request.view.render(
      "admin/recipe-form",
      AdminRecipeFormContext(
        pageTitle: recipe == nil ? "Recept toevoegen" : "Recept wijzigen",
        heading: recipe == nil ? "Recept toevoegen" : "Recept wijzigen",
        username: try identity(request).username, csrfToken: AdminSession.csrfToken(for: request),
        action: action, returnPath: request.url.path,
        title: recipe?.title ?? "", summary: recipe?.summary ?? "",
        sourceURL: recipe?.sourceURL ?? "",
        durationMinutes: recipe.map { String($0.durationMinutes) } ?? "",
        imagePath: recipe?.imagePath,
        sources: try sources.map { option(try $0.requireID(), $0.name, recipe?.$source.id, false) },
        ingredients: try ingredients.map {
          option(try $0.requireID(), $0.name, nil, ingredientIDs.contains(try $0.requireID()))
        },
        dietaryPreferences: try preferences.map {
          option(try $0.requireID(), $0.name, nil, preferenceIDs.contains(try $0.requireID()))
        },
        publishedCheckedAttribute: recipe?.isPublished == true ? "checked" : "",
        errorMessage: nil))
  }

  private func option(_ id: UUID, _ name: String, _ selected: UUID?, _ checked: Bool)
    -> AdminOptionContext
  {
    .init(
      id: id.uuidString, name: name, selectedAttribute: id == selected ? "selected" : "",
      checkedAttribute: checked ? "checked" : "")
  }

  private func validateOffer(_ form: OfferForm, request: Request) async throws
    -> ValidatedOffer
  {
    var ingredientIDs: [UUID] = []
    for rawID in form.ingredientIDs ?? [] {
      if let id = UUID(uuidString: rawID), !ingredientIDs.contains(id) {
        ingredientIDs.append(id)
      }
    }
    guard !ingredientIDs.isEmpty else {
      throw Abort(.unprocessableEntity, reason: "Kies minimaal één ingrediënt.")
    }
    guard ingredientIDs.count <= 500 else {
      throw Abort(.unprocessableEntity, reason: "Kies maximaal 500 ingrediënten.")
    }
    let existingCount = try await ManagedIngredient.query(on: request.db)
      .filter(\.$id ~~ Set(ingredientIDs)).count()
    guard existingCount == ingredientIDs.count else {
      throw Abort(.unprocessableEntity, reason: "Een gekozen ingrediënt bestaat niet meer.")
    }
    guard let supermarketID = UUID(uuidString: form.supermarketID),
      try await ManagedSupermarket.find(supermarketID, on: request.db) != nil
    else {
      throw Abort(.unprocessableEntity, reason: "Kies een bestaande supermarkt.")
    }
    let from = try AdminValidation.localDate(form.validFrom)
    let until = try AdminValidation.localDate(form.validUntil, endOfDay: true)
    guard until >= from else {
      throw Abort(.unprocessableEntity, reason: "De einddatum mag niet vóór de begindatum liggen.")
    }
    return ValidatedOffer(
      supermarketID: supermarketID, ingredientIDs: ingredientIDs,
      validFrom: from, validUntil: until)
  }

  private func validateRecipe(_ form: RecipeForm, request: Request) async throws
    -> ValidatedRecipe
  {
    guard let sourceID = UUID(uuidString: form.sourceID),
      try await RecipeSourceRecord.find(sourceID, on: request.db) != nil
    else {
      throw Abort(.unprocessableEntity, reason: "Kies een bestaande receptbron.")
    }
    let ingredientIDs = Set((form.ingredientIDs ?? []).compactMap(UUID.init(uuidString:)))
    guard !ingredientIDs.isEmpty else {
      throw Abort(.unprocessableEntity, reason: "Kies minimaal één ingrediënt.")
    }
    let existingCount = try await ManagedIngredient.query(on: request.db).filter(
      \.$id ~~ ingredientIDs
    ).count()
    guard existingCount == ingredientIDs.count else {
      throw Abort(.unprocessableEntity, reason: "Een gekozen ingrediënt bestaat niet meer.")
    }
    let preferenceIDs = Set(
      (form.dietaryPreferenceIDs ?? []).compactMap(UUID.init(uuidString:)))
    let preferenceCount = try await ManagedDietaryPreference.query(on: request.db)
      .filter(\.$id ~~ preferenceIDs).count()
    guard preferenceCount == preferenceIDs.count else {
      throw Abort(.unprocessableEntity, reason: "Een gekozen gerechtswens bestaat niet meer.")
    }
    return ValidatedRecipe(
      title: try AdminValidation.text(form.title, field: "de titel"),
      summary: try AdminValidation.text(form.summary, field: "de samenvatting", maximum: 500),
      url: try AdminValidation.webURL(form.sourceURL, field: "de receptlink"),
      duration: try AdminValidation.positiveInt(
        form.durationMinutes, field: "de bereidingstijd", maximum: 1_440),
      sourceID: sourceID, ingredientIDs: Array(ingredientIDs),
      dietaryPreferenceIDs: Array(preferenceIDs)
    )
  }

  private func identity(_ request: Request) throws -> AdminIdentity {
    guard let identity = AdminSession.identity(for: request) else { throw Abort(.unauthorized) }
    return identity
  }

  private func find<M: Model>(_ type: M.Type, _ request: Request) async throws -> M
  where M.IDValue == UUID {
    guard let rawID = request.parameters.get("id"), let id = UUID(uuidString: rawID),
      let model = try await M.find(id, on: request.db)
    else { throw Abort(.notFound) }
    return model
  }

  private func saveAndAudit<M: Model>(_ model: M, entity: String, request: Request) async throws
  where M.IDValue == UUID {
    let actor = try identity(request).username
    try await request.db.transaction { database in
      try await model.save(on: database)
      try await AdminAuditEntry(
        actor: actor, action: "create", entityType: entity,
        entityID: try model.requireID()
      ).save(on: database)
    }
  }

  private func updateAndAudit<M: Model>(_ model: M, entity: String, request: Request) async throws
  where M.IDValue == UUID {
    let actor = try identity(request).username
    let id = try model.requireID()
    try await request.db.transaction { database in
      try await model.update(on: database)
      try await AdminAuditEntry(actor: actor, action: "update", entityType: entity, entityID: id)
        .save(on: database)
    }
  }

  private func delete<M: Model>(_ type: M.Type, entity: String, request: Request) async throws
    -> Response where M.IDValue == UUID
  {
    let form = try request.content.decode(AdminCSRFForm.self)
    try AdminSession.requireCSRF(form.csrfToken, for: request)
    let model = try await find(type, request)
    let actor = try identity(request).username
    let id = try model.requireID()
    try await request.db.transaction { database in
      try await model.delete(on: database)
      try await AdminAuditEntry(actor: actor, action: "delete", entityType: entity, entityID: id)
        .save(on: database)
    }
    return request.redirect(
      to: entity == "recipe_source"
        ? "/admin/recipe-sources"
        : entity == "dietary_preference"
          ? "/admin/dietary-preferences"
          : entity == "offer" ? "/admin/offers" : "/admin/\(entity)s"
    )
  }

  private func safeReturn(_ value: String?, fallback: String) -> String {
    let allowed = ["/admin/offers/new", "/admin/recipes/new"]
    guard let value else { return fallback }
    if allowed.contains(value) { return value }
    let parts = value.split(separator: "/")
    if parts.count == 4, parts[0] == "admin", ["offers", "recipes"].contains(parts[1]),
      UUID(uuidString: String(parts[2])) != nil, parts[3] == "edit"
    {
      return value
    }
    return fallback
  }

  private func searchTerm(_ request: Request) -> String {
    String(
      (request.query[String.self, at: "q"] ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
  }

  private func searchableText(_ values: [String]) -> String {
    values.joined(separator: " ").folding(
      options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_NL"))
  }

  private func listPath(_ basePath: String, page: Int, search: String) -> String {
    var components = URLComponents()
    components.path = basePath
    components.queryItems = [URLQueryItem(name: "page", value: String(page))]
    if !search.isEmpty { components.queryItems?.append(URLQueryItem(name: "q", value: search)) }
    return components.string ?? basePath
  }

  private func preferenceSlug(_ name: String) -> String {
    name.folding(
      options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_NL")
    ).lowercased()
      .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
      .joined(separator: "-")
  }

  private func pageNumber(_ request: Request) -> Int {
    guard let query = request.url.query,
      let components = URLComponents(string: "?\(query)"),
      let value = components.queryItems?.first(where: { $0.name == "page" })?.value,
      let page = Int(value), page > 0, page <= 10_000
    else { return 1 }
    return page
  }
}
