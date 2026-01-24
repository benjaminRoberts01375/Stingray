//
//  APIBasicNetwork.swift
//  Stingray
//
//  Created by Ben Roberts on 12/11/25.
//

import SwiftUI

/// A very basic network protocol for sending/receving requests, as well as formatting options
public protocol BasicNetworkProtocol {
    /// Makes a web REST request
    /// - Parameters:
    ///   - verb: Type of REST request
    ///   - path: URL path without hostname, leading slashes, or URL params
    ///   - headers: Headers to add to request
    ///   - urlParams: URL paramaters for data fields
    ///   - body: For sending more advanced data structures like JSON
    /// - Returns: A formatted response in a Decodable type
    func request<T: Decodable>(
        verb: NetworkRequestType,
        path: String,
        headers: [String : String]?,
        urlParams: [URLQueryItem]?,
        body: (any Encodable)?
    ) async throws -> T
    
    /// Allows simple URL building using the URL type.
    /// - Parameters:
    ///   - path: Path to a particular resource without the hostname, leading slashes, or URL params
    ///   - urlParams: URL params to add to URL
    /// - Returns: Formatted URL
    func buildURL(path: String, urlParams: [URLQueryItem]?) -> URL?
}

/// Basic descriptor for REST API verbs
public enum NetworkRequestType: String {
    /// Corresponds to the GET REST API verb
    case get = "GET"
    /// Corresponds to the PUT REST API verb
    case put = "PUT"
    /// Corresponds to the POST REST API verb
    case post = "POST"
    /// Corresponds to the DELETE REST API verb
    case delete = "DELETE"
}

public enum NetworkError: RError {
    /// The request URL was invalid.
    case invalidURL(String)
    /// Could not encode JSON.
    case encodeJSONFailed(Error)
    /// Could not send the payload
    case requestFailedToSend(Error)
    /// Response was bad in some way
    case badResponse(responseCode: Int, response: String?)
    /// Could not decode the returned JSON
    case decodeJSONFailed(Error, url: URL?)
    /// An access token is needed
    case missingAccessToken
    
    var next: (any Error)? {
        switch self {
        case .invalidURL, .badResponse, .missingAccessToken:
            return nil
        case .encodeJSONFailed(let error), .requestFailedToSend(let error), .decodeJSONFailed(let error, _):
            return error
        }
    }
    
    public var errorDescription: String {
        switch self {
        case .invalidURL(let description):
            return "The requested URL was invalid: \(description)"
        case .encodeJSONFailed:
            return "Unable to encode JSON"
        case .requestFailedToSend:
            return "Request failed to send"
        case .badResponse(let code, let text):
            return "Received a bad response from the server - \(code) \(text ?? "")"
        case .decodeJSONFailed(let error, let url): // Special handling for decode errors
            let urlString = url?.absoluteString ?? "unknown URL"
            // Provide detailed information about decoding errors
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                    return "Unable to decode JSON from \(urlString): Missing key '\(key.stringValue)' at \(path)"
                case .valueNotFound(let type, let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                    return "Unable to decode JSON from \(urlString): Missing value of type '\(type)' at \(path)"
                case .typeMismatch(let type, let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                    return """
                        Unable to decode JSON from \(urlString): Type mismatch for '\(type)' at \(path). \
                        \(context.debugDescription)
                        """
                case .dataCorrupted(let context):
                    let path = context.codingPath.map { $0.stringValue }.joined(separator: " -> ")
                    return """
                        Unable to decode JSON from \(urlString): Data corrupted at \(path). \
                        \(context.debugDescription)
                        """
                @unknown default:
                    return "Unable to decode JSON from \(urlString): \(error.localizedDescription)"
                }
            }
            return "Failed to decode JSON"
        case .missingAccessToken:
            return "An access token is needed"
        }
    }
}

/// A Jellyfin specific basic network struct for making network requests
public final class JellyfinBasicNetwork: BasicNetworkProtocol {
    var address: URL
    
    init(address: URL) { self.address = address }
    
    public func request<T: Decodable>(
        verb: NetworkRequestType,
        path: String,
        headers: [String : String]? = nil,
        urlParams: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil
    ) async throws -> T {
        // Setup URL with path
        guard let url = self.buildURL(path: path, urlParams: urlParams) else {
            throw NetworkError.invalidURL("\(self.address.absoluteString) + \(path) + \(urlParams?.debugDescription ?? "No params")")
        }
        
        print("Reaching out to \(url.absoluteString)")
        
        // Setup request
        var request = URLRequest(url: url)
        request.httpMethod = verb.rawValue
        
        // Jellyfin headers
        let (deviceId, deviceName) = await MainActor.run {
            let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            let name = UIDevice.current.name
            return (id, name)
        }
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
            } catch {
                throw NetworkError.encodeJSONFailed(error)
            }
        }
        
        // Send the request
        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw NetworkError.requestFailedToSend(error)
        }
        
        // Verify not invalid status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.badResponse(responseCode: 0, response: "Not an HTTP response")
        }
        
        // Verify non-bad status code
        if !(200...299).contains(httpResponse.statusCode) {
            throw NetworkError.badResponse(
                responseCode: httpResponse.statusCode,
                response: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }
        
        // Decode the JSON response with more helpful errors
        do {
            let decodedResponse = try JSONDecoder().decode(T.self, from: responseData)
            return decodedResponse
        } catch let DecodingError.dataCorrupted(context) {
            throw NetworkError.decodeJSONFailed(DecodingError.dataCorrupted(context), url: url)
        } catch let DecodingError.keyNotFound(key, context) {
            throw NetworkError.decodeJSONFailed(DecodingError.keyNotFound(key, context), url: url)
        } catch let DecodingError.valueNotFound(value, context) {
            throw NetworkError.decodeJSONFailed(DecodingError.valueNotFound(value, context), url: url)
        } catch let DecodingError.typeMismatch(type, context) {
            throw NetworkError.decodeJSONFailed(DecodingError.typeMismatch(type, context), url: url)
        } catch {
            throw NetworkError.decodeJSONFailed(error, url: url)
        }
    }
    
    public func buildURL(path: String, urlParams: [URLQueryItem]?) -> URL? {
        return self.address.buildURL(path: path, urlParams: urlParams)
    }
}
