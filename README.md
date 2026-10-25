<img src="PlayIt/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png" width="128" alt="g-play icon">

# g-play

An iPhone music player for the device's Music library. See [DESIGN.md](DESIGN.md) and [PLAN.md](PLAN.md).

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
