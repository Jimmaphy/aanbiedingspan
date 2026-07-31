import Foundation

struct AdminLoginContext: Encodable {
  let pageTitle = "Inloggen voor beheer"
  let csrfToken: String
  let errorMessage: String?
  let isConfigured: Bool
}

struct AdminShellContext: Encodable {
  let pageTitle: String
  let heading: String
  let introduction: String
  let username: String
  let csrfToken: String
}

struct AdminErrorContext: Encodable {
  let pageTitle = "Beheerfout"
  let heading: String
  let message: String
  let backPath: String
}

struct AdminListItemContext: Encodable {
  let id: String
  let title: String
  let detail: String
}

struct AdminListContext: Encodable {
  let pageTitle: String
  let heading: String
  let introduction: String
  let username: String
  let csrfToken: String
  let basePath: String
  let createLabel: String
  let searchTerm: String
  let searchResultMessage: String?
  let emptyMessage: String
  let items: [AdminListItemContext]
  let previousPath: String?
  let nextPath: String?
}

struct AdminOptionContext: Encodable {
  let id: String
  let name: String
  let selectedAttribute: String
  let checkedAttribute: String
}

struct AdminSimpleFormContext: Encodable {
  let pageTitle: String
  let heading: String
  let username: String
  let csrfToken: String
  let action: String
  let cancelPath: String
  let name: String
  let websiteURL: String
  let showsWebsiteURL: Bool
  let errorMessage: String?
}

struct AdminOfferFormContext: Encodable {
  let pageTitle: String
  let heading: String
  let username: String
  let csrfToken: String
  let action: String
  let returnPath: String
  let ingredients: [AdminOptionContext]
  let supermarkets: [AdminOptionContext]
  let validFrom: String
  let validUntil: String
  let errorMessage: String?
}

struct AdminRecipeFormContext: Encodable {
  let pageTitle: String
  let heading: String
  let username: String
  let csrfToken: String
  let action: String
  let returnPath: String
  let title: String
  let summary: String
  let sourceURL: String
  let durationMinutes: String
  let imagePath: String?
  let sources: [AdminOptionContext]
  let ingredients: [AdminOptionContext]
  let dietaryPreferences: [AdminOptionContext]
  let errorMessage: String?
}
