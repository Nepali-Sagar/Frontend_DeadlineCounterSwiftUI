# Deadline Counter — iOS App (SwiftUI)

A native iOS app built with **SwiftUI** that helps you track and manage deadlines. It connects to a REST API backend and works **offline** — changes sync automatically when your connection is restored.

> 📌 This is the frontend client. The backend API lives in a separate repository.  
> **Backend repo:** _[add your backend GitHub repo link here]_

---

## ✨ Features

- **Live countdown** — each deadline shows a real-time countdown (e.g. `2d 4h left`, `Overdue by 3d`)
- **Offline-first** — create, edit, and delete deadlines without internet; changes sync when online
- **Categories** — organise deadlines into Study, Work, Personal, Health, or Other
- **Urgent flag** — mark time-sensitive deadlines as urgent
- **Search & filter** — search by title and filter by category or completion status
- **Network status indicator** — app shows live sync status (syncing, offline, up-to-date)
- **Add / Edit / Delete** — full CRUD via a clean form sheet
- **Persistent local storage** — deadlines survive app restarts even without internet

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Minimum iOS | iOS 17+ |
| Networking | `URLSession` (async/await) |
| Offline queue | Custom `PendingChange` queue persisted to JSON |
| Local storage | `LocalDeadlineStore` (JSON file in Documents) |
| Network monitoring | `Network.framework` (`NWPathMonitor`) |
| Backend | Node.js REST API (deployed on Render) |

---

## 📁 Project Structure

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

## 🚀 Getting Started

### Prerequisites

- **macOS** with Xcode 15 or later installed
- **iOS Simulator** or a physical iPhone/iPad (iOS 17+)
- The backend API running (locally or deployed — see backend repo)

### 1. Clone the repo

```bash
git clone <your-frontend-repo-url>
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

> ⚠️ If you use `localhost` on a physical device, make sure your phone and Mac are on the same Wi-Fi network and use your Mac's local IP address instead.

### 3. Open in Xcode and run

```bash
open DeadlineCounterSwiftUI.xcodeproj
```

- Select your target simulator or device in the Xcode toolbar
- Press **⌘ + R** (or click ▶) to build and run

---

## 🔄 Offline Sync — How It Works

1. When you create, update, or delete a deadline **without internet**, the change is saved to a local pending-changes queue (`pending-deadline-changes.json`).
2. The app also saves the current list of deadlines to `deadlines.json` so the UI always shows the latest state.
3. When internet is restored, `ConnectivityMonitor` detects the change and triggers a sync.
4. The sync replays each queued operation against the backend API in order (create → update → delete).
5. After syncing, the app fetches the latest deadlines from the server to reconcile any conflicts.

---

## 🌐 Backend API

This app talks to a **Node.js + Express** REST API with the following endpoints:

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/deadlines` | Fetch all deadlines |
| `POST` | `/api/deadlines` | Create a new deadline |
| `PUT` | `/api/deadlines/:id` | Update an existing deadline |
| `DELETE` | `/api/deadlines/:id` | Delete a deadline |

The backend is deployed on **Render**. See the backend repo for setup instructions.

---

## 📝 Notes

- This project was built as a learning exercise to explore **Xcode**, **Swift**, and **SwiftUI** and understand how iOS apps communicate with a REST API.
- The app uses `clientID` to track deadlines across local and server state — the server assigns a MongoDB `_id` while the app maintains its own UUID-based local ID.
- No third-party Swift packages or CocoaPods are used — purely Swift standard library + Apple frameworks.

---

## 📄 License

This project is for personal/educational use.
