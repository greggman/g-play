# Play-It - an iPhone Music Player

This app plays the iPhone's built in Music Library.

## Features

* Search by track name, artist, album
* Play all tracks shuffled weighted by recently played

  The goal is to listen to your entire library where as unweighted
  means repeats are more likely.

  A shuffle is a fixed order, shown in full in Up Next: songs already
  played (dimmed), the current one, then the rest. Tap any song to carry on
  from there. At the end it starts over in the same order, so every song
  plays once per time through; only Reshuffle makes a new order. Playing
  something else saves the library-wide shuffle, and Shuffle All picks it up
  where it left off. Songs added to the library are shuffled in after the
  current song, weighted like the rest, so they tend to come early.

* has all the normal music player features
  * play/pause
  * queue slider
  * prev/next track
  * shows album art while playing
  * plays even when the app is not in the front
  * plays on the lock screen with album art
  * clicking the album art on the lock screen goes to that album
  * clicking an artist's name goes to that artist (not a search, which also shows other artists).
    Only on the playing song and in the artist list; in song lists the artist
    is plain text so tapping anywhere on a song plays it
  * has list of music sorted by
    * track name
    * album name
    * artist name
    * date added to collection


## Play Design

* You have a mode, examples

  * play all tracks
  * play playlist
  * play album
  * play artist
  * play track

  On top of the mode there is a "top playlist" or "top queue".
  If anything is in the top queue then that is played. If the "top queue"
  is empty then it goes back to the mode.

  * For any result you can you can do one of the following
    * play the result (your new mode)
    * put the result on the top of the top queue and play immediate. (play now)
    * put the result at the top of the top queue so it will play next (play next)
    * put the result at the bottom of the top queue (play after recently queued)

## Use Best Practices

It should go without saying, use best practices.
Also, always let the user long press to copy (copy artist name, copy track name, copy album name). Of course other options can appear on a long press but "copy" should always be one of them

## Testing

Test on the Simulator.