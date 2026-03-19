import Foundation

struct FileItem: Identifiable, Codable, Hashable {
    var id: String { path }

    let name: String
    let path: String
    let type: FileType
    let size: Int64?
    let mode: Int?
    let uid: Int?
    let gid: Int?
    let acl: Bool?

    // TrueNAS returns these as nested objects with `$date` keys
    // We handle both formats in custom decoding
    let modified: Date?

    enum FileType: String, Codable {
        case file = "FILE"
        case directory = "DIRECTORY"
        case symlink = "SYMLINK"
        case other = "OTHER"

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            self = FileType(rawValue: raw) ?? .other
        }
    }

    enum CodingKeys: String, CodingKey {
        case name, path, type, size, mode, uid, gid, acl
        case modified = "realpath" // placeholder - we decode manually
    }

    init(name: String, path: String, type: FileType, size: Int64?, modified: Date?) {
        self.name = name
        self.path = path
        self.type = type
        self.size = size
        self.mode = nil
        self.uid = nil
        self.gid = nil
        self.acl = nil
        self.modified = modified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        name = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: "name")!)
        path = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: "path")!)
        type = try container.decode(FileType.self, forKey: DynamicCodingKeys(stringValue: "type")!)
        size = try container.decodeIfPresent(Int64.self, forKey: DynamicCodingKeys(stringValue: "size")!)
        mode = try container.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "mode")!)
        uid = try container.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "uid")!)
        gid = try container.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "gid")!)
        acl = try container.decodeIfPresent(Bool.self, forKey: DynamicCodingKeys(stringValue: "acl")!)

        // TrueNAS returns dates as either epoch or {"$date": epoch_ms}
        if let dateContainer = try? container.nestedContainer(
            keyedBy: DynamicCodingKeys.self,
            forKey: DynamicCodingKeys(stringValue: "date")!
        ), let ms = try? dateContainer.decode(Int64.self, forKey: DynamicCodingKeys(stringValue: "$date")!) {
            modified = Date(timeIntervalSince1970: Double(ms) / 1000.0)
        } else if let epoch = try? container.decode(Double.self, forKey: DynamicCodingKeys(stringValue: "date")!) {
            modified = Date(timeIntervalSince1970: epoch)
        } else {
            modified = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        try container.encode(name, forKey: DynamicCodingKeys(stringValue: "name")!)
        try container.encode(path, forKey: DynamicCodingKeys(stringValue: "path")!)
        try container.encode(type, forKey: DynamicCodingKeys(stringValue: "type")!)
        try container.encodeIfPresent(size, forKey: DynamicCodingKeys(stringValue: "size")!)
    }

    var isDirectory: Bool { type == .directory }

    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }

    var isImage: Bool {
        ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic"].contains(fileExtension)
    }

    var isText: Bool {
        ["txt", "md", "json", "xml", "yaml", "yml", "csv", "log", "conf", "cfg",
         "sh", "bash", "zsh", "py", "js", "ts", "swift", "c", "h", "cpp", "rs",
         "go", "rb", "php", "html", "css", "toml", "ini"].contains(fileExtension)
    }

    var isVideo: Bool {
        ["mp4", "mov", "m4v"].contains(fileExtension)
    }

    var isAudio: Bool {
        ["mp3", "flac", "wav", "aac", "m4a", "ogg"].contains(fileExtension)
    }

    var isArchive: Bool {
        ["zip", "tar", "gz", "7z", "rar", "bz2", "xz"].contains(fileExtension)
    }

    var isCode: Bool {
        ["swift", "py", "js", "ts", "c", "h", "cpp", "rs", "go", "rb", "php",
         "java", "kt", "sh", "bash", "zsh", "css", "html"].contains(fileExtension)
    }

    var iconName: String {
        if isDirectory { return "folder.fill" }
        if isImage { return "photo.fill" }
        if isVideo { return "film.fill" }
        if isAudio { return "music.note" }
        if isArchive { return "doc.zipper" }
        if isCode { return "chevron.left.forwardslash.chevron.right" }
        if isText { return "doc.text.fill" }
        switch fileExtension {
        case "pdf": return "doc.richtext.fill"
        default: return "doc.fill"
        }
    }

    static let mockFiles: [FileItem] = [
        FileItem(name: "mnt", path: "/mnt", type: .directory, size: nil, modified: Date()),
        FileItem(name: "documents", path: "/mnt/tank/documents", type: .directory, size: nil, modified: Date()),
        FileItem(name: "photos", path: "/mnt/tank/photos", type: .directory, size: nil, modified: Date()),
        FileItem(name: "readme.md", path: "/mnt/tank/readme.md", type: .file, size: 4096, modified: Date()),
        FileItem(name: "backup.tar.gz", path: "/mnt/tank/backup.tar.gz", type: .file, size: 1_073_741_824, modified: Date().addingTimeInterval(-86400)),
        FileItem(name: "vacation.jpg", path: "/mnt/tank/vacation.jpg", type: .file, size: 5_242_880, modified: Date().addingTimeInterval(-172800)),
        FileItem(name: "config.yaml", path: "/mnt/tank/config.yaml", type: .file, size: 2048, modified: Date().addingTimeInterval(-3600)),
        FileItem(name: "movie.mkv", path: "/mnt/tank/movie.mkv", type: .file, size: 4_294_967_296, modified: Date().addingTimeInterval(-259200)),
    ]
}

struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
