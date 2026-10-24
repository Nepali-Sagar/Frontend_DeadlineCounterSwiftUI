import Foundation
import Combine

@MainActor
final class DeadlineAPI: ObservableObject {
    @Published private(set) var deadlines: [Deadline] = []
    @Published var isLoading = false
    @Published private(set) var isSyncing = false
    @Published private(set) var syncStatus = "Checking synchronization"
    @Published var errorMessage: String?

    struct APIError: LocalizedError {
        let statusCode: Int
        var errorDescription: String? {
            "HTTP error \(statusCode)"
        }
    }

    private let baseURL = "https://deadline-counter.onrender.com/api/deadlines"
    private var syncInProgress = false
    private var inFlightLoadTask: Task<Void, Never>?

    private struct DeadlinePayload: Encodable {
        let clientID: String?
        let title: String
        let dueDate: Date
        let isUrgent: Bool
        let category: String
        let isCompleted: Bool

        init(_ deadline: Deadline, includeClientID: Bool = true) {
            self.clientID = includeClientID ? deadline.id : nil
            title = deadline.title
            dueDate = deadline.dueDate
            isUrgent = deadline.isUrgent
            category = deadline.category
            isCompleted = deadline.isCompleted
        }

        enum CodingKeys: String, CodingKey {
            case clientID, title, dueDate, isUrgent, category, isCompleted
        }
    }

    private struct DeadlinesResponse: Decodable {
        let success: Bool
        let data: [Deadline]
    }

    private struct DeadlineResponse: Decodable {
        let success: Bool
        let data: Deadline
    }

    private struct PendingChange: Codable, Identifiable {
        enum Operation: String, Codable { case create, update, delete }
        var id: String { localID }
        let localID: String
        var serverID: String?
        var operation: Operation
        var deadline: Deadline?
    }

    private let queueURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending-deadline-changes.json")
    }()

    private func loadQueue() throws -> [PendingChange] {
        guard FileManager.default.fileExists(atPath: queueURL.path) else { return [] }
        let data = try Data(contentsOf: queueURL)
        return try JSONDecoder().decode([PendingChange].self, from: data)
    }

    private func saveQueue(_ queue: [PendingChange]) throws {
        let data = try JSONEncoder().encode(queue)
        try data.write(to: queueURL, options: .atomic)
    }

    private func enqueue(_ operation: PendingChange.Operation, deadline: Deadline) throws {
        var queue = try loadQueue()
        let existing = queue.first { $0.localID == deadline.id }
        queue.removeAll { $0.localID == deadline.id }

        let serverID = deadline.serverID ?? existing?.serverID
        let next: PendingChange.Operation
        if operation == .delete {
            // A local-only create can be cancelled without ever reaching the server.
            if existing?.operation == .create && serverID == nil && !syncInProgress {
                try saveQueue(queue)
                return
            }
            next = .delete
        } else if existing?.operation == .create && serverID == nil {
            next = .create
        } else {
            next = operation
        }

        queue.append(PendingChange(
            localID: deadline.id,
            serverID: serverID,
            operation: next,
            deadline: next == .delete ? nil : deadline
        ))
        try saveQueue(queue)
    }

    private func persistVisibleDeadlines() throws {
        try LocalDeadlineStore.shared.save(deadlines)
    }

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.httpMaximumConnectionsPerHost = 6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    @discardableResult
    private func request(_ url: URL, method: String, body: Data? = nil) async throws -> (data: Data, statusCode: Int) {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError(statusCode: http.statusCode)
        }
        return (data, http.statusCode)
    }

    private func isCancelled(_ error: Error) -> Bool {
        (error as? URLError)?.code == .cancelled ||
        (error as NSError).code == NSURLErrorCancelled
    }

    func loadAllData() async {
        if let existing = inFlightLoadTask {
            await existing.value
            return
        }

        let task = Task { @MainActor in
            await performLoadAllData()
        }
        inFlightLoadTask = task
        await task.value
        inFlightLoadTask = nil
    }

    private func performLoadAllData() async {
        isLoading = true
        defer {
            isLoading = false
        }

        do {
            let local = try LocalDeadlineStore.shared.loadThrowing()
            let currentQueue = try loadQueue()
            deadlines = merge(remote: nil, local: local, queue: currentQueue)

            if !currentQueue.isEmpty {
                try await syncPendingChanges()
            }

            let (data, _) = try await request(URL(string: baseURL)!, method: "GET")
            let response = try decoder().decode(DeadlinesResponse.self, from: data)
            guard response.success else { throw URLError(.cannotParseResponse) }

            let currentLocal = try LocalDeadlineStore.shared.loadThrowing()
            deadlines = merge(remote: response.data, local: currentLocal, queue: try loadQueue())
            try persistVisibleDeadlines()
            let pending = try loadQueue().isEmpty == false
            syncStatus = pending ? "Changes waiting to sync" : "All changes synced"
            errorMessage = pending ? "Changes are waiting to sync." : nil
        } catch {
            if !isCancelled(error) {
                print("LOAD/SYNC ERROR:", error)
                syncStatus = "Sync issue"
                errorMessage = "Sync incomplete: \(error.localizedDescription)"
            }
        }
    }

    private func merge(remote: [Deadline]?, local: [Deadline], queue: [PendingChange]) -> [Deadline] {
        guard let remote else {
            var result = local
            for change in queue {
                if change.operation == .delete {
                    result.removeAll { $0.id == change.localID || $0.serverID == change.serverID }
                } else if let item = change.deadline {
                    result.removeAll { $0.id == item.id }
                    result.append(item)
                }
            }
            return result.sorted { $0.dueDate < $1.dueDate }
        }

        var result = remote.map { item -> Deadline in
            var copy = item
            let remoteID = item.serverID ?? item.id
            if let existing = local.first(where: { $0.serverID == remoteID || $0.id == item.id }) {
                copy.id = existing.id
            }
            copy.serverID = remoteID
            return copy
        }

        // Preserve local records that are still queued; hide tombstoned records.
        for change in queue {
            result.removeAll { $0.id == change.localID || (change.serverID != nil && $0.serverID == change.serverID) }
            if change.operation != .delete, let item = change.deadline { result.append(item) }
        }
        return result.sorted { $0.dueDate < $1.dueDate }
    }

    func addDeadline(_ deadline: Deadline) async {
        if !deadlines.contains(where: { $0.id == deadline.id }) { deadlines.append(deadline) }
        await recordAndSync(.create, deadline: deadline)
    }

    func updateDeadline(_ deadline: Deadline) async {
        if let index = deadlines.firstIndex(where: { $0.id == deadline.id }) {
            deadlines[index] = deadline
        } else {
            deadlines.append(deadline)
        }
        await recordAndSync(deadline.serverID == nil ? .create : .update, deadline: deadline)
    }

    func deleteDeadline(_ deadline: Deadline) async {
        deadlines.removeAll { $0.id == deadline.id }
        do {
            // Persist the tombstone/operation before the visible snapshot so a disk error
            // cannot leave a deletion without a durable retry record.
            try enqueue(.delete, deadline: deadline)
            try persistVisibleDeadlines()
            try await syncPendingChanges()
            let pending = try loadQueue().isEmpty == false
            syncStatus = pending ? "Changes waiting to sync" : "All changes synced"
            errorMessage = pending ? "Deletion is waiting to sync." : nil
        } catch {
            print("DELETE/SYNC ERROR:", error)
            errorMessage = "Deleted locally; synchronization is pending. \(error.localizedDescription)"
        }
    }

    private func recordAndSync(_ operation: PendingChange.Operation, deadline: Deadline) async {
        do {
            // Write the durable operation first. The queue can reconstruct the visible
            // local state after relaunch even if the snapshot write fails.
            try enqueue(operation, deadline: deadline)
            try persistVisibleDeadlines()
            try await syncPendingChanges()
            let pending = try loadQueue().isEmpty == false
            syncStatus = pending ? "Changes waiting to sync" : "All changes synced"
            errorMessage = pending ? "Changes are waiting to sync." : nil
        } catch {
            print("SAVE/SYNC ERROR:", error)
            errorMessage = "Changes are saved locally; synchronization is pending. \(error.localizedDescription)"
        }
    }

    private func syncPendingChanges() async throws {
        guard !syncInProgress else { return }
        syncInProgress = true
        isSyncing = true
        syncStatus = "Synchronizing"
        defer {
            syncInProgress = false
            isSyncing = false
        }

        var queue = try loadQueue()
        guard !queue.isEmpty else {
            syncStatus = "All changes synced"
            return
        }

        var processed: [String] = []
        var newServerIDs: [String: String] = [:]

        await withTaskGroup(of: (String, String?, Bool).self) { group in
            for change in queue {
                group.addTask { @MainActor [weak self] in
                    guard let self else { return (change.localID, nil, false) }
                    return await self.executeChange(change)
                }
            }
            for await (localID, serverID, success) in group {
                if success {
                    processed.append(localID)
                    if let serverID {
                        newServerIDs[localID] = serverID
                    }
                }
            }
        }

        for (localID, serverID) in newServerIDs {
            if let idx = deadlines.firstIndex(where: { $0.id == localID }) {
                deadlines[idx].serverID = serverID
            }
            for i in queue.indices where queue[i].localID == localID {
                queue[i].serverID = serverID
                queue[i].deadline?.serverID = serverID
            }
        }

        queue.removeAll { processed.contains($0.localID) }
        try saveQueue(queue)
        try persistVisibleDeadlines()
    }

    private func executeChange(_ change: PendingChange) async -> (localID: String, serverID: String?, success: Bool) {
        do {
            switch change.operation {
            case .create:
                guard let deadline = change.deadline else { return (change.localID, nil, true) }
                let payload = try encoder().encode(DeadlinePayload(deadline))
                let (data, _) = try await request(URL(string: baseURL)!, method: "POST", body: payload)
                let response = try decoder().decode(DeadlineResponse.self, from: data)
                guard response.success else { return (change.localID, nil, false) }
                let serverID = response.data.serverID ?? response.data.id
                return (change.localID, serverID, true)

            case .update:
                guard let deadline = change.deadline else { return (change.localID, nil, true) }
                let sid = change.serverID ?? deadline.serverID
                guard let sid else { return (change.localID, nil, false) }
                let url = URL(string: "\(baseURL)/\(sid)")!
                let payload = try encoder().encode(DeadlinePayload(deadline, includeClientID: false))
                let (data, _) = try await request(url, method: "PUT", body: payload)
                let response = try decoder().decode(DeadlineResponse.self, from: data)
                return (change.localID, sid, response.success)

            case .delete:
                guard let sid = change.serverID else {
                    return (change.localID, nil, true)
                }
                let url = URL(string: "\(baseURL)/\(sid)")!
                _ = try await request(url, method: "DELETE")
                return (change.localID, nil, true)
            }
        } catch let error as APIError {
            if error.statusCode == 404 || error.statusCode == 400 {
                print("Unrecoverable HTTP \(error.statusCode) for \(change.operation) on \(change.localID). Dropping from retry queue.")
                return (change.localID, nil, true)
            }
            print("SYNC item transient HTTP error (\(error.statusCode)):", error)
            return (change.localID, nil, false)
        } catch {
            if !isCancelled(error) {
                print("SYNC item error (\(change.operation)):", error)
            }
            return (change.localID, nil, false)
        }
    }
}
