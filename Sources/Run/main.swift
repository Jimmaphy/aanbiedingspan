import App
import Vapor

var environment = try Environment.detect()
try LoggingSystem.bootstrap(from: &environment)
let application = try await Application.make(environment)

do {
  try await configure(application)
  try await application.execute()
  try await application.asyncShutdown()
} catch {
  try? await application.asyncShutdown()
  throw error
}
