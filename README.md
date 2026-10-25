<img src="PlayIt/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png" width="128" alt="g-play icon">

# g-play

An iPhone music player for the device's Music library. 

## Why?

1. The built in player has bad shuffle such that for years
   I didn't hear 80-90% of my music collection
3. I switch to Foobar2000 which did much better on shuffle
   and used it for years
4. There were a few features I wanted that Foobar2000 was
   missing and thought maybe someday I'd write a player
5. Foobar2000 died on me one day. It locked up and resetting
   the app (flinging its screen off the switching on iOS did 
   not fix it.

It's October 2026 so I said, F! and vibed it. 3 hours later this popped out.
It run and had the features I wanted to add

* It lets me see tracks by date added to my collection

  With 8000 tracks, I recently added 20 more and could never find them in Foobar2000.
  Now I can

* It lets me add tracks to a queue in front of what's currently playing.

  Flow in Foobar2000 was (1) Shuffle (2) Think of song I want to hear, search, pick it
  (3) song plays over and over forever unless I manually go back to shuffle.

  Flow in g-play (1) Shuffle (2) Add track to temp queue. It plays and goes back to
  the shuffle list. You can queue more tracks to be added to this temp queue. You can
  add them to the front or the end of this temp queue. When done it will go back to
  whatever it was doing before (shuffle, album, etc...)

See [DESIGN.md](DESIGN.md) and [PLAN.md](PLAN.md).

Note: The point isn't to use this app. You can if you want. I'm not sure if I'll spend the time
to try to get it on the store though. The point is in 2-3 hours an AI can build the solution
that fits exactly what you personally want. No needed to wish someone else would add a feature.

## Building

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
open PlayIt.xcodeproj
```

Or from the command line:

```sh
scripts/build.sh            # build for the Simulator
scripts/build.sh test       # run unit and UI tests
scripts/run-sim.sh          # install, launch and screenshot on the Simulator
scripts/install-device.sh   # build, install and launch on a connected iPhone
```

## The Simulator

The Simulator has no music library, so on the Simulator the app uses a generated
library (`FixtureMusicLibrary`) and plays a bundled tone through `AVPlayer` for
every track. Launch arguments:

| Argument | Effect |
|---|---|
| `-fixtureTrackCount N` | Size of the generated library (default 400) |
| `-systemLibrary` | Use the real library / system player on the Simulator |
| `-fixtureLibrary` | Use the generated library on a device |
| `-resetState` | Forget the saved queue, playlists and preferences |
