import Foundation
import SwiftUI
import UIKit

enum TrueNASError: LocalizedError {
    case noAPIKey
    case invalidURL
    case httpError(Int, String?)
    case networkError(Error)
    case decodingError(Error)
    case serverUnreachable

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured"
        case .invalidURL:
            return "Invalid server URL"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message ?? "Unknown error")"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data error: \(error.localizedDescription)"
        case .serverUnreachable:
            return "Server unreachable"
        }
    }
}

// MARK: - Thumbnail Cache

actor ThumbnailCache {
    static let shared = ThumbnailCache()
    private var cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func get(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ key: String, image: UIImage) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

@MainActor
class TrueNASService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isConnecting = false
    @Published var connectionError: String?
    @Published var useMockData = false

    private var apiKey: String?
    private let session: URLSession
    private var activeTasks: [String: Task<Void, Never>] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)

        // Try loading saved key
        if let savedKey = KeychainHelper.loadAPIKey() {
            self.apiKey = savedKey
        }
    }

    func cancelTasks(for scope: String) {
        activeTasks[scope]?.cancel()
        activeTasks.removeValue(forKey: scope)
    }

    func trackTask(_ scope: String, task: Task<Void, Never>) {
        activeTasks[scope]?.cancel()
        activeTasks[scope] = task
    }

    // MARK: - Request Helpers

    /// Build a GET request (for no-argument endpoints like system/info)
    private func getRequest(endpoint: String, key: String) -> URLRequest? {
        guard let url = URL(string: "\(ServerConfig.baseURL)/\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// Build a POST request with a JSON body (dict or array)
    private func postRequest(endpoint: String, key: String, body: Any) throws -> URLRequest {
        guard let url = URL(string: "\(ServerConfig.baseURL)/\(endpoint)") else {
            throw TrueNASError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Auth

    func authenticate(apiKey: String, serverAddress: String) async -> Bool {
        isConnecting = true
        connectionError = nil

        ServerConfig.savedAddress = serverAddress

        guard let request = getRequest(endpoint: "system/info", key: apiKey) else {
            connectionError = "Invalid server address"
            isConnecting = false
            return false
        }

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                connectionError = "Invalid response"
                isConnecting = false
                return false
            }

            if httpResponse.statusCode == 200 {
                self.apiKey = apiKey
                _ = KeychainHelper.saveAPIKey(apiKey)
                isAuthenticated = true
                isConnecting = false
                return true
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                connectionError = "Invalid API key"
                isConnecting = false
                return false
            } else {
                connectionError = "Server returned \(httpResponse.statusCode)"
                isConnecting = false
                return false
            }
        } catch {
            connectionError = "Cannot reach server: \(error.localizedDescription)"
            isConnecting = false
            return false
        }
    }

    func tryAutoLogin() async {
        guard let savedKey = KeychainHelper.loadAPIKey() else { return }
        _ = await authenticate(apiKey: savedKey, serverAddress: ServerConfig.savedAddress)
    }

    func logout() {
        apiKey = nil
        isAuthenticated = false
        _ = KeychainHelper.deleteAPIKey()
    }

    // MARK: - File Operations

    func listDirectory(path: String) async throws -> [FileItem] {
        if useMockData { return FileItem.mockFiles }

        guard let key = apiKey else { throw TrueNASError.noAPIKey }

        let request = try postRequest(endpoint: "filesystem/listdir", key: key, body: ["path": path])

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TrueNASError.serverUnreachable
            }

            guard httpResponse.statusCode == 200 else {
                let message = String(data: data, encoding: .utf8)
                throw TrueNASError.httpError(httpResponse.statusCode, message)
            }

            do {
                let items = try JSONDecoder().decode([FileItem].self, from: data)
                return items.sorted { a, b in
                    if a.isDirectory != b.isDirectory { return a.isDirectory }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
            } catch {
                throw TrueNASError.decodingError(error)
            }
        } catch let error as TrueNASError {
            throw error
        } catch {
            throw TrueNASError.networkError(error)
        }
    }

    func downloadFile(path: String) async throws -> (Data, String) {
        if useMockData {
            return ("Mock file content for: \(path)".data(using: .utf8)!, (path as NSString).lastPathComponent)
        }

        guard let key = apiKey else { throw TrueNASError.noAPIKey }
        guard let url = URL(string: "\(ServerConfig.baseURL)/filesystem/get") else {
            throw TrueNASError.invalidURL
        }

        // TrueNAS expects a bare JSON string as the body, e.g. "/mnt/pool/file.txt"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(path)

        do {
            let (data, response) = try await session.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let code = httpResponse?.statusCode ?? 0

            guard code == 200 else {
                let message = String(data: data, encoding: .utf8)
                throw TrueNASError.httpError(code, message)
            }

            // If the server returned JSON instead of file bytes, it's an error payload
            if let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type"),
               contentType.contains("application/json") {
                let message = String(data: data, encoding: .utf8)
                throw TrueNASError.httpError(code, message ?? "Server returned JSON instead of file data")
            }

            return (data, (path as NSString).lastPathComponent)
        } catch let error as TrueNASError {
            throw error
        } catch {
            throw TrueNASError.networkError(error)
        }
    }

    func uploadFile(path: String, data: Data) async throws {
        guard let key = apiKey else { throw TrueNASError.noAPIKey }
        guard let url = URL(string: "\(ServerConfig.baseURL)/filesystem/put") else {
            throw TrueNASError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // JSON params part: [path, {}]
        let params = try JSONSerialization.data(withJSONObject: [path, ["mode": nil] as [String: Any?]])
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"data\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        body.append(params)
        body.append("\r\n".data(using: .utf8)!)

        // File data part
        let filename = (path as NSString).lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        // Closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (responseData, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let message = String(data: responseData, encoding: .utf8)
                throw TrueNASError.httpError(code, message ?? "Upload failed")
            }
        } catch let error as TrueNASError {
            throw error
        } catch {
            throw TrueNASError.networkError(error)
        }
    }

    func fetchThumbnail(path: String, maxSize: CGFloat = 80) async -> UIImage? {
        // Check cache first
        if let cached = await ThumbnailCache.shared.get(path) {
            return cached
        }

        guard let (data, _) = try? await downloadFile(path: path) else { return nil }
        guard let full = UIImage(data: data) else { return nil }

        // Downscale for thumbnail
        let scale = min(maxSize / full.size.width, maxSize / full.size.height, 1.0)
        let newSize = CGSize(width: full.size.width * scale, height: full.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let thumb = renderer.image { _ in
            full.draw(in: CGRect(origin: .zero, size: newSize))
        }

        await ThumbnailCache.shared.set(path, image: thumb)
        return thumb
    }

    func getFileStat(path: String) async throws -> FileItem {
        guard let key = apiKey else { throw TrueNASError.noAPIKey }

        let request = try postRequest(endpoint: "filesystem/stat", key: key, body: ["path": path])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = String(data: data, encoding: .utf8)
            throw TrueNASError.httpError(code, message)
        }

        return try JSONDecoder().decode(FileItem.self, from: data)
    }

    func testConnection() async -> Bool {
        guard let key = apiKey else { return false }
        guard var request = getRequest(endpoint: "system/info", key: key) else { return false }
        request.timeoutInterval = 5

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
