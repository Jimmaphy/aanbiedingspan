import Foundation
import Vapor

enum RecipeImageStorage {
  static let maximumBytes = 5 * 1_024 * 1_024

  static func save(_ file: File?, for request: Request) async throws -> String? {
    guard let file, file.data.readableBytes > 0 else { return nil }
    let fileExtension = try validatedExtension(for: file)
    let filename = "\(UUID().uuidString.lowercased()).\(fileExtension)"
    let directory = request.application.directory.publicDirectory + "uploads/recipes/"
    try FileManager.default.createDirectory(
      atPath: directory, withIntermediateDirectories: true)
    try await request.fileio.writeFile(file.data, at: directory + filename)
    return "/uploads/recipes/\(filename)"
  }

  static func validatedExtension(for file: File) throws -> String {
    guard file.data.readableBytes <= maximumBytes else {
      throw Abort(.payloadTooLarge, reason: "De afbeelding mag maximaal 5 MB zijn.")
    }
    guard file.data.readableBytes > 0,
      let bytes = file.data.getBytes(
        at: file.data.readerIndex, length: min(file.data.readableBytes, 12))
    else {
      throw Abort(.unprocessableEntity, reason: "Kies een geldige afbeelding.")
    }
    if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
    if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return "png" }
    if bytes.count >= 12, Array(bytes[0..<4]) == [0x52, 0x49, 0x46, 0x46],
      Array(bytes[8..<12]) == [0x57, 0x45, 0x42, 0x50]
    {
      return "webp"
    }
    throw Abort(
      .unprocessableEntity,
      reason: "Gebruik een afbeelding als JPEG, PNG of WebP.")
  }

  static func remove(_ imagePath: String?, for request: Request) {
    guard let imagePath, imagePath.hasPrefix("/uploads/recipes/"),
      !imagePath.dropFirst("/uploads/recipes/".count).contains("/")
    else { return }
    let path = request.application.directory.publicDirectory + String(imagePath.dropFirst())
    try? FileManager.default.removeItem(atPath: path)
  }
}
