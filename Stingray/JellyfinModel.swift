//
//  JellyfinModel.swift
//  Stingray
//
//  Created by Ben Roberts on 11/13/25.
//

import AVKit

protocol StreamingServiceProtocol {
    var url: URL? { get }
    var accessToken: String? { get }
    var networkAPI: AdvancedNetworkProtocol { get }
    var storageAPI: AdvancedStorageProtocol { get }
    
    func login(username: String, password: String) async throws
    func getLibraries() async throws -> [LibraryModel]
    func getStreamingContent(mediaSource: any MediaSourceProtocol) -> AVPlayerItem?
}

@Observable
final class JellyfinModel: StreamingServiceProtocol {
    var networkAPI: AdvancedNetworkProtocol
    var storageAPI: AdvancedStorageProtocol
    
    var url: URL? {
        didSet { storageAPI.setServerURL(url) }
    }
    
    var usersName: String? {
        didSet { storageAPI.setUsersName(usersName) }
    }
    
    var usersID: String? {
        didSet { storageAPI.setUserID(usersID) }
    }
    
    var sessionID: String? {
        didSet { storageAPI.setSessionID(sessionID) }
    }
    
    var accessToken: String? {
        didSet { storageAPI.setAccessToken(accessToken)}
    }
    
    var serverID: String? {
        didSet { storageAPI.setServerID(serverID) }
    }
    
    init(address: URL?) throws {
        enum AddressError: Error {
            case badAddress
        }
        
        guard let address = address else { throw AddressError.badAddress }
        self.networkAPI = JellyfinAdvancedNetwork(network: JellyfinBasicNetwork(address: address))
        self.storageAPI = DefaultsAdvancedStorage(storage: DefaultsBasicStorage())
        self.url = address
        self.usersName = storageAPI.getUsersName()
        self.usersID = storageAPI.getUserID()
        self.sessionID = storageAPI.getSessionID()
        self.accessToken = storageAPI.getAccessToken()
        self.serverID = storageAPI.getServerID()
        print("URL: \(url?.absoluteString  ?? "None available")")
        print("User's Name: \(usersName ?? "None available")")
        print("UserID: \(usersID ?? "None available")")
        print("SessionID: \(sessionID ?? "None available")")
        print("Access Token: \(accessToken ?? "None available")")
        print("ServerID: \(serverID ?? "None available")")
    }
    
    func login(username: String, password: String) async throws {
        let response = try await networkAPI.login(username: username, password: password)
        self.usersName = response.userName
        self.usersID = response.userId
        self.sessionID = response.sessionId
        self.accessToken = response.accessToken
        self.serverID = response.serverId
    }
    
    func getLibraries() async throws -> [LibraryModel] {
        guard let accessToken else { throw NetworkError.missingAccessToken }
        return try await networkAPI.getLibraries(accessToken: accessToken)
    }
    
    func getStreamingContent(mediaSource: any MediaSourceProtocol) -> AVPlayerItem? {
        guard let accessToken = accessToken else { return nil }
        return networkAPI.getStreamingContent(accessToken: accessToken, contentID: mediaSource.id, streamID: String(mediaSource.id), bitrate: mediaSource.videoStreams[0].bitrate ?? 6000)
    }
}
