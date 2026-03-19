import Foundation

enum Formatters {
    static func fileSize(_ bytes: Int64?) -> String {
        guard let bytes = bytes, bytes > 0 else { return "--" }

        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var unitIndex = 0

        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.1f %@", size, units[unitIndex])
    }

    static func relativeDate(_ date: Date?) -> String {
        guard let date = date else { return "--" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func shortDate(_ date: Date?) -> String {
        guard let date = date else { return "--" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func pathComponents(_ path: String) -> [(name: String, path: String)] {
        let cleaned = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let parts = cleaned.split(separator: "/").map(String.init)
        var components: [(name: String, path: String)] = [("root", "/")]
        var currentPath = ""

        for part in parts {
            currentPath += "/\(part)"
            components.append((part, currentPath))
        }

        return components
    }
}
