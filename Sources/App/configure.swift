import Fluent
import FluentPostgresDriver
import Leaf
import Vapor

public func configure(_ app: Application) async throws {
  app.middleware.use(SecurityHeadersMiddleware())
  app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

  let secureAdminCookie = app.environment == .production
  app.sessions.configuration = .init(cookieName: "aanbiedingspan-admin") { sessionID in
    HTTPCookies.Value(
      string: sessionID.string,
      expires: Date(timeIntervalSinceNow: 60 * 60 * 8),
      maxAge: nil, domain: nil, path: "/admin", isSecure: secureAdminCookie,
      isHTTPOnly: true, sameSite: .lax)
  }
  app.middleware.use(app.sessions.middleware)

  app.views.use(.leaf)
  app.leaf.cache.isEnabled = app.environment == .production

  let databaseConfiguration = SQLPostgresConfiguration(
    hostname: Environment.get("DATABASE_HOST") ?? "127.0.0.1",
    port: Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432,
    username: Environment.get("DATABASE_USERNAME") ?? "aanbiedingspan",
    password: Environment.get("DATABASE_PASSWORD") ?? "development-only",
    database: Environment.get("DATABASE_NAME") ?? "aanbiedingspan",
    tls: .disable
  )
  app.databases.use(.postgres(configuration: databaseConfiguration), as: .psql)
  app.migrations.add(CreateAdminCatalog())
  app.migrations.add(CreateOfferIngredients())
  app.migrations.add(AddRecipeMediaAndPreferences())

  let configuredRole = Environment.get("ADMIN_ROLE") ?? "admin"
  app.adminAuth = AdminAuthConfiguration(
    username: Environment.get("ADMIN_USERNAME"),
    passwordHash: Environment.get("ADMIN_PASSWORD_HASH"),
    role: ["admin", "editor"].contains(configuredRole) ? configuredRole : "editor")

  app.catalog = .demo
  try routes(app)
}
