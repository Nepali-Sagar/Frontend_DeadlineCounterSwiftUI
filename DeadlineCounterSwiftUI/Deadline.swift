
import Foundation

struct Deadline: Identifiable, Codable {
    var id: String
    var serverID: String?
    var title: String
    var dueDate: Date
    var isUrgent: Bool
    var category: String
    var isCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id = "localID"
        case clientID
        case serverID = "_id"
        case title
        case dueDate
        case isUrgent
        case category
        case isCompleted
    }

    init(
        id: String = UUID().uuidString,
        serverID: String? = nil,
        title: String,
        dueDate: Date,
        isUrgent: Bool = false,
        category: String = "Study",
        isCompleted: Bool = false
    ) {
        self.id = id
        self.serverID = serverID
        self.title = title
        self.dueDate = dueDate
        self.isUrgent = isUrgent
        self.category = category
        self.isCompleted = isCompleted
    }

    // Supports both local JSON and MongoDB API responses.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let localID = try container.decodeIfPresent(String.self, forKey: .id)
        let clientID = try container.decodeIfPresent(String.self, forKey: .clientID)
        let remoteID = try container.decodeIfPresent(String.self, forKey: .serverID)

        id = localID ?? clientID ?? remoteID ?? UUID().uuidString
        serverID = remoteID

        title = try container.decode(String.self, forKey: .title)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        isUrgent = try container.decodeIfPresent(Bool.self, forKey: .isUrgent) ?? false
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Study"
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(serverID, forKey: .serverID)
        try container.encode(title, forKey: .title)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(isUrgent, forKey: .isUrgent)
        try container.encode(category, forKey: .category)
        try container.encode(isCompleted, forKey: .isCompleted)
    }

    var isOverdue: Bool {
        !isCompleted && dueDate < Date()
    }

    var countdownText: String {
        if isCompleted { return "Completed" }

        let seconds = Int(dueDate.timeIntervalSinceNow)

        if seconds < 0 {
            let days = abs(seconds) / 86400 
            return days == 0 ? "Overdue today" : "Overdue by \(days)d"
        }

        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600

        if days > 0 {
            return "\(days)d \(hours)h left"
        }

        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }

        return "\(minutes)m left"
    }
}
