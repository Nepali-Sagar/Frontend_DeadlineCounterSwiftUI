# Deadline Counter — iOS App (SwiftUI)

A native iOS app built with **SwiftUI** that helps you track and manage deadlines. It connects to a REST API backend and works **offline** — changes sync automatically when your connection is restored.

> This is the frontend client. The backend API lives in a separate repository.  
> **Backend repo:** https://github.com/Nepali-Sagar/Backend_Deadline-Counter

---

## Features

- **Live countdown** — each deadline shows a real-time countdown (e.g. `2d 4h left`, `Overdue by 3d`)
- **Offline-first** — create, edit, and delete deadlines without internet; changes sync when online
- **Categories** — organise deadlines into Study, Work, Personal, Health, or Other
- **Urgent flag** — mark time-sensitive deadlines as urgent
- **Search and filter** — search by title and filter by category or completion status
- **Network status indicator** — app shows live sync status (syncing, offline, up-to-date)
- **Add / Edit / Delete** — full CRUD via a clean form sheet
- **Persistent local storage** — deadlines survive app restarts even without internet

---

## Tech Stack

| Layer              | Technology                                      |
|--------------------|-------------------------------------------------|
| Language           | Swift 5.9+                                      |
| UI Framework       | SwiftUI                                         |
| Minimum iOS        | iOS 17+                                         |
| Networking         | `URLSession` (async/await)                      |
| Offline queue      | Custom `PendingChange` queue persisted to JSON  |
| Local storage      | `LocalDeadlineStore` (JSON file in Documents)   |
| Network monitoring | `Network.framework` (`NWPathMonitor`)           |
| Backend            | Node.js REST API (deployed on Render)           |

---

## Project Structure

```
DeadlineCounterSwiftUI/
├── DeadlineCounterSwiftUI.xcodeproj/   # Xcode project file
└── DeadlineCounterSwiftUI/
    ├── MyApp.swift                     # App entry point (@main)
    ├── ContentView.swift               # Main list + header UI
    ├── DeadlineFormView.swift          # Add / Edit deadline sheet
    ├── Deadline.swift                  # Deadline model (Codable)
    ├── DeadlineAPI.swift               # API client + offline sync logic
    ├── LocalDeadlineStore.swift        # Persist deadlines locally (JSON)
    ├── ConnectivityMonitor.swift       # NWPathMonitor network watcher
    └── Assets.xcassets/               # App icons and colour assets
```

---

## Getting Started

### Prerequisites

- macOS with Xcode 15 or later installed
- iOS Simulator or a physical iPhone/iPad running iOS 17+
- The backend API running locally or deployed (see backend repo)

### 1. Clone the repository

```bash
git clone https://github.com/Nepali-Sagar/Frontend_DeadlineCounterSwiftUI.git
cd DeadlineCounterSwiftUI
```

### 2. Configure the backend URL

Open `DeadlineCounterSwiftUI/DeadlineAPI.swift` and update the `baseURL` constant to point to your backend:

```swift
// Line ~19 in DeadlineAPI.swift
private let baseURL = "https://your-backend-url.onrender.com/api/deadlines"
```

If running the backend locally, use:

```swift
private let baseURL = "http://127.0.0.1:3000/api/deadlines"
```

> **Note:** If testing on a physical device with a local server, replace `127.0.0.1` with your Mac's local IP address. Both devices must be on the same Wi-Fi network.

### 3. Open in Xcode and run

```bash
open DeadlineCounterSwiftUI.xcodeproj
```

Select your target simulator or device in the Xcode toolbar, then press **Cmd + R** to build and run.

---

## Offline Sync

When there is no internet connection, the app continues to work normally. Here is how changes are handled:

1. Any create, update, or delete action is recorded in a local pending-changes queue (`pending-deadline-changes.json`).
2. The current list of deadlines is also saved to `deadlines.json` so the UI always reflects the latest local state.
3. When internet is restored, `ConnectivityMonitor` detects the change and triggers a sync automatically.
4. The sync replays each queued operation against the backend API in order (create, then update, then delete).
5. After syncing, the app fetches the latest deadlines from the server to reconcile any differences.

---

## Backend API

This app communicates with a Node.js + Express REST API. The following endpoints are used:

| Method   | Endpoint              | Description                  |
|----------|-----------------------|------------------------------|
| GET      | `/api/deadlines`      | Fetch all deadlines          |
| POST     | `/api/deadlines`      | Create a new deadline        |
| PUT      | `/api/deadlines/:id`  | Update an existing deadline  |
| DELETE   | `/api/deadlines/:id`  | Delete a deadline            |

The backend is deployed on Render. See the backend repository for setup and deployment instructions.

---

## Notes

- This project was built as a learning exercise to understand Xcode, Swift, SwiftUI, and how iOS apps communicate with a REST API.
- The app uses a `clientID` field to track deadlines across local and server state. The server assigns a MongoDB `_id`, while the app maintains its own UUID-based local identifier.
- No third-party Swift packages or CocoaPods are used. The project relies entirely on the Swift standard library and Apple frameworks.

---

## License

This project is for personal and educational use.
