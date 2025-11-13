//
//  APINetwork.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import SwiftUI

public protocol BasicNetworkProtocol {
    func request<T: Decodable>(verb: NetworkRequestType, path: String, headers: [String: String]?, body: Encodable?) async throws -> T
}

public enum NetworkRequestType: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

public enum NetworkError: Error, LocalizedError {
    case invalidURL
    case encodeJSONFailed(Error)
    case requestFailedToSend(Error)
    case badResponse(responseCode: Int, response: String?)
    case decodeJSONFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodeJSONFailed (let error):
            return "Unable to encode JSON: \(error.localizedDescription)"
        case .requestFailedToSend(let error):
            return "The request failed to send: \(error.localizedDescription)"
        case .badResponse(let responseCode, let response):
            return "Got a bad response from the server. Error: \(responseCode), \(response ?? "Unknown error")"
        case .decodeJSONFailed(let error):
            return "Unable to decode JSON: \(error.localizedDescription)"
        }
    }
}

public protocol AdvancedNetworkProtocol {
    func login(username: String, password: String) async throws -> APILoginResponse
}

public struct APILoginResponse: Decodable {
    let userName: String
    let sessionId: String
    let userId: String
    let accessToken: String
    let serverId: String
    
    enum CodingKeys: String, CodingKey {
        case user = "User"
        case sessionInfo = "SessionInfo"
        case accessToken = "AccessToken"
        case serverId = "ServerId"
    }
    
    enum UserKeys: String, CodingKey {
        case name = "Name"
    }
    
    enum SessionInfoKeys: String, CodingKey {
        case id = "Id"
        case userId = "UserId"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode nested User
        let userContainer = try container.nestedContainer(keyedBy: UserKeys.self, forKey: .user)
        userName = try userContainer.decode(String.self, forKey: .name)
        
        // Decode nested SessionInfo
        let sessionContainer = try container.nestedContainer(keyedBy: SessionInfoKeys.self, forKey: .sessionInfo)
        sessionId = try sessionContainer.decode(String.self, forKey: .id)
        userId = try sessionContainer.decode(String.self, forKey: .userId)
        
        // Decode flat fields
        accessToken = try container.decode(String.self, forKey: .accessToken)
        serverId = try container.decode(String.self, forKey: .serverId)
    }
}

final class JellyfinBasicNetwork: BasicNetworkProtocol {
    var address: URL
    
    init(address: URL) {
        self.address = address
    }
    
    func request<T: Decodable>(verb: NetworkRequestType, path: String, headers: [String : String]?, body: (any Encodable)?) async throws -> T {
        // Setup URL with path
        guard let url = URL(string: path, relativeTo: address) else {
            throw NetworkError.invalidURL
        }
        
        // Setup request
        var request = URLRequest(url: url)
        request.httpMethod = verb.rawValue
        
        // Jellyfin headers
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let deviceName = UIDevice.current.name
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let authHeader = "MediaBrowser Client=\"Stingray\", Device=\"\(deviceName)\", DeviceId=\"\(deviceId)\", Version=\"\(appVersion)\""
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        // Only add custom headers if they are provided
        if let headers = headers {
            for header in headers {
                request.setValue(header.1, forHTTPHeaderField: header.0)
            }
        }
        
        // Only encode body if one is provided
        if let body = body {
            let jsonData: Data
            do {
                jsonData = try JSONEncoder().encode(body)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type") // Set JSON as content type
                request.httpBody = jsonData
            } catch (let error) {
                throw NetworkError.encodeJSONFailed(error)
            }
        }
        
        // Send the request
        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await URLSession.shared.data(for: request)
        } catch (let error) {
            throw NetworkError.requestFailedToSend(error)
        }
        
        // Verify not invalid status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.badResponse(responseCode: 0, response: "Not an HTTP response")
        }
        
        // Verify non-bad status code
        if !(200...299).contains(httpResponse.statusCode) {
            throw NetworkError.badResponse(responseCode: httpResponse.statusCode, response: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
        }
        
        // Decode the JSON response
        do {
            // Print the response for debugging
            if let responseString = String(data: responseData, encoding: .utf8) {
                print("Response JSON: \(responseString)")
            }
            
            let decodedResponse = try JSONDecoder().decode(T.self, from: responseData)
            return decodedResponse
        } catch (let error) {
            throw NetworkError.decodeJSONFailed(error)
        }
    }
}

final class JellyfinAdvancedNetwork: AdvancedNetworkProtocol {
    var network: BasicNetworkProtocol
    
    init(network: BasicNetworkProtocol) {
        self.network = network
    }
    
    func login(username: String, password: String) async throws -> APILoginResponse {
        struct Response: Codable {
            let User: User
            let SessionInfo: SessionInfo
            let AccessToken: String
            let ServerId: String
        }
        
        struct User: Codable {
            let Name: String
        }
        
        struct SessionInfo: Codable {
            let Id: String
            let UserId: String
        }
        
        let requestBody: [String: String] = [
            "Username": username,
            "Pw": password
        ]
        return try await network.request(verb: .post, path: "/Users/AuthenticateByName", headers: nil, body: requestBody)
    }
}
