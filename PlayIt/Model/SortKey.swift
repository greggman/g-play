import Foundation

/// Sorting and searching helpers that match how the Music app orders names.
enum SortKey {
  private static let articles = ["the ", "a ", "an "]

  /// Case-, diacritic- and width-insensitive form of `s`.
  static func fold(_ s: String) -> String {
    s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
  }

  /// Folded, with a leading "The", "A" or "An" removed, so "The Beatles"
  /// sorts under B.
  static func make(_ s: String) -> String {
    let folded = fold(s).trimmingCharacters(in: .whitespacesAndNewlines)
    for article in articles where folded.hasPrefix(article) && folded.count > article.count {
      return String(folded.dropFirst(article.count))
    }
    return folded
  }

  static func less(_ a: String, _ b: String) -> Bool {
    a.localizedStandardCompare(b) == .orderedAscending
  }
}
