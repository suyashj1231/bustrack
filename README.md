# BusTrack

A personal tracker for UCI's Anteater Express. It uses the same live TransLoc feed as shuttle.uci.edu.

The Favorites tab lists your starred stops with the next buses on each line, refreshed every 15 seconds. The Live Map shows buses moving along the route lines (every 5 seconds); tap a stop to see its arrivals. All Stops lets you search every stop and star the ones you use.

On a stop's screen, tap the 🔔 next to a line and pick 1, 3, 5 or 10 minutes to get a bus-is-close alert. There's also a widget for the home screen (small or medium) and the lock screen. Long-press it, choose **Edit Widget**, and pick a stop.

## Build

```sh
brew install xcodegen      # one time
xcodegen generate          # re-run whenever you add or remove files
open BusTrack.xcodeproj
```

Run the tests: `xcodebuild test -project BusTrack.xcodeproj -scheme BusTrack -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

## Install on your iPhone (free Apple ID)

1. In Xcode, go to Settings › Accounts and add your Apple ID.
2. Select the **BusTrack** target, open Signing & Capabilities, and set Team to *(Your Name) (Personal Team)*.
3. Do the same for the **BusTrackWidget** target.
4. If Xcode says the bundle ID is taken, change `com.suyashjain` in `project.yml` to something unique and re-run `xcodegen generate`.
5. Plug in your iPhone. On the phone, turn on **Developer Mode** (Settings › Privacy & Security), then choose your phone as the run destination and press ▶.
6. On the phone, trust the developer: Settings › General › VPN & Device Management › your Apple ID › Trust.
7. With a free account the app **expires after 7 days**. Plug the phone in and press ▶ again to renew it.

## Known limits

- iOS limits how often widgets reload. The widget fetches about every 5 minutes and counts down minute by minute in between, so it's good for a quick glance. Open the app for exact times.
- A free Apple account can't receive push notifications, so alerts are scheduled from the estimate and updated whenever the app runs. If the app is closed and the bus speeds up or slows down, the alert can be off by about a minute.
- The data comes from TransLoc's unofficial `ucirvine.transloc.com/Services/JSONPRelay.svc` endpoints, which could change at any time.

## Code map

- `Shared/`: the TransLoc client, models, stop grouping (one stop = one `AddressID`), arrival math and the polyline decoder. Used by both the app and the widget.
- `BusTrack/`: the SwiftUI app.
- `BusTrackWidget/`: the WidgetKit extension, with stop selection through an AppIntent.
- `BusTrackTests/`: tests against trimmed copies of real API responses.
