import Foundation
import SwiftUI

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

@MainActor
class TrueNASService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isConnecting = false
    @Published var connectionError: String?
    @Published var useMockData = false

    private var apiKey: String?
    private let session: URLSession

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

    // MARK: - Auth

    func authenticate(apiKey: String, serverAddress: String) async -> Bool {
        isConnecting = true
        connectionError = nil

        ServerConfig.savedAddress = serverAddress

        guard let url = URL(string: "\(ServerConfig.baseURL)/system/info") else {
            connectionError = "Invalid server address"
            isConnecting = false
            return false
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

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

        var components = URLComponents(string: "\(ServerConfig.baseURL)/filesystem/listdir/")
        components?.queryItems = [URLQueryItem(name: "path", value: path)]
        guard let url = components?.url else {
            throw TrueNASError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

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

        guard let url = URL(string: "\(ServerConfig.baseURL)/filesystem/get/") else {
            throw TrueNASError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["path": path])

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = String(data: data, encoding: .utf8)
            throw TrueNASError.httpError(code, message ?? "Download failed")
        }

        let filename = (path as NSString).lastPathComponent
        return (data, filename)
    }

    func getFileStat(path: String) async throws -> FileItem {
        guard let key = apiKey else { throw TrueNASError.noAPIKey }

        var components = URLComponents(string: "\(ServerConfig.baseURL)/filesystem/stat/")
        components?.queryItems = [URLQueryItem(name: "path", value: path)]
        guard let url = components?.url else {
            throw TrueNASError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw TrueNASError.httpError(code, nil)
        }

        return try JSONDecoder().decode(FileItem.self, from: data)
    }

    func testConnection() async -> Bool {
        guard let key = apiKey else { return false }
        guard let url = URL(string: "\(ServerConfig.baseURL)/system/info") else { return false }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
