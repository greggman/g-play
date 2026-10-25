import Foundation

/// What plays when the top queue is empty.
enum PlayMode: Hashable, Sendable, Codable {
  /// Every track, weighted-shuffled toward ones not played recently.
  case allTracks
  case playlist(PlaylistID)
  case album(Album.ID)
  case artist(Artist.ID)
  case track(Track.ID)
  /// Library → Songs, in title order.
  case songs
  /// Library → Added, newest first.
  case recentlyAdded
  /// The songs found by a search.
  case searchResults(String)
}
