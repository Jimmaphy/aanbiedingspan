import Foundation
import Vapor

enum AdminValidation {
  static func text(_ value: String, field: String, maximum: Int = 120) throws -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw Abort(.badRequest, reason: "Vul \(field) in.") }
    guard trimmed.count <= maximum else {
      throw Abort(
        .badRequest, reason: "\(field.capitalized) mag maximaal \(maximum) tekens hebben.")
    }
    return trimmed
  }

  static func optionalWebURL(_ value: String) throws -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    return try webURL(trimmed, field: "websiteadres")
  }

  static func webURL(_ value: String, field: String) throws -> String {
    guard value.count <= 2_000, let components = URLComponents(string: value),
      ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
      components.host != nil
    else { throw Abort(.badRequest, reason: "Vul bij \(field) een volledig webadres in.") }
    return value
  }

  static func positiveInt(_ value: String, field: String, maximum: Int) throws -> Int {
    guard let number = Int(value), number > 0, number <= maximum else {
      throw Abort(.badRequest, reason: "Vul bij \(field) een getal van 1 tot en met \(maximum) in.")
    }
    return number
  }

  static func email(_ value: String) throws -> String {
    let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = email.split(separator: "@", omittingEmptySubsequences: false)
    let allowedLocal = CharacterSet.alphanumerics.union(
      CharacterSet(charactersIn: ".!#$%&'*+/=?^_`{|}~-"))
    let allowedDomain = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
    guard email.count <= 254, parts.count == 2,
      !parts[0].isEmpty, parts[0].count <= 64,
      parts[1].contains("."), !parts[1].hasPrefix("."), !parts[1].hasSuffix("."),
      !email.contains(".."),
      parts[0].unicodeScalars.allSatisfy(allowedLocal.contains),
      parts[1].unicodeScalars.allSatisfy(allowedDomain.contains)
    else {
      throw Abort(.badRequest, reason: "Vul een geldig e-mailadres in.")
    }
    return email
  }

  static func localDate(_ value: String, endOfDay: Bool = false) throws -> Date {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    guard let date = formatter.date(from: value) else {
      throw Abort(.badRequest, reason: "Vul een geldige datum in.")
    }
    return endOfDay
      ? Calendar(identifier: .gregorian).date(byAdding: .second, value: 86_399, to: date)! : date
  }

  static func dateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "nl_NL")
    formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}
