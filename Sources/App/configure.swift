import Fluent
import FluentPostgresDriver
import Leaf
import Vapor

public func configure(_ app: Application) async throws {
  app.middleware.use(SecurityHeadersMiddleware())
  app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

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

  app.catalog = .demo
  try routes(app)
}
