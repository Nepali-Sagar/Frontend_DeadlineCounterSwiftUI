import Foundation

enum LocalDeadlineStoreError: LocalizedError {
    case corruptStore

    var errorDescription: String? {
        switch self {
        case .corruptStore:
            return "The saved deadlines file could not be decoded. The original file was preserved."
        }
    }
}

final class LocalDeadlineStore {
    static let shared = LocalDeadlineStore()
    private let fileURL: URL

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("deadlines.json")
    }

    func loadThrowing() throws -> [Deadline] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Deadline].self, from: data)
        } catch {
            throw LocalDeadlineStoreError.corruptStore
        }
    }

    // Kept for source compatibility; synchronization code uses loadThrowing().
    func load() -> [Deadline] {
        (try? loadThrowing()) ?? []
    }

    func save(_ deadlines: [Deadline]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(deadlines)
        try data.write(to: fileURL, options: .atomic)
    }
}
