//
//  settings.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

@Observable
final class JellyfinManager {
    private let defaults = UserDefaults.standard
    
    var urlProtocol: HttpProtocol {
        didSet { defaults.set(urlProtocol.rawValue, forKey: DefaultsKeys.urlProtocol.rawValue) }
    }
    
    var urlHostname: String {
        didSet { defaults.set(urlHostname, forKey: DefaultsKeys.urlHostname.rawValue) }
    }
    
    var urlPort: String {
        didSet { defaults.set(urlPort, forKey: DefaultsKeys.urlPort.rawValue) }
    }
    
    var usersName: String {
        didSet { defaults.set(usersName, forKey: DefaultsKeys.usersName.rawValue)}
    }
    
    var sessionID: String {
        didSet { defaults.set(sessionID, forKey: DefaultsKeys.sessionID.rawValue)}
    }
    
    var userID: String {
        didSet { defaults.set(userID, forKey: DefaultsKeys.userID.rawValue)}
    }
    
    var accessToken: String {
        didSet { defaults.set(accessToken, forKey: DefaultsKeys.accessToken.rawValue) }
    }
    
    var serverID: String {
        didSet { defaults.set(serverID, forKey: DefaultsKeys.serverID.rawValue) }
    }
    
    init() {
        self.urlProtocol = HttpProtocol(rawValue: defaults.string(forKey: DefaultsKeys.urlProtocol.rawValue) ?? "") ?? .http
        self.urlHostname = defaults.string(forKey: DefaultsKeys.urlHostname.rawValue) ?? ""
        self.urlPort = defaults.string(forKey: DefaultsKeys.urlPort.rawValue) ?? "8096"
        self.usersName = defaults.string(forKey: DefaultsKeys.usersName.rawValue) ?? ""
        self.sessionID = defaults.string(forKey: DefaultsKeys.sessionID.rawValue) ?? ""
        self.userID = defaults.string(forKey: DefaultsKeys.userID.rawValue) ?? ""
        self.accessToken = defaults.string(forKey: DefaultsKeys.accessToken.rawValue) ?? ""
        self.serverID = defaults.string(forKey: DefaultsKeys.serverID.rawValue) ?? ""
    }
    
    var url: URL? {
        get {
            if urlHostname == "" {
                return nil
            }
            return URL(string: "\(urlProtocol)://\(urlHostname):\(urlPort)/")
        }
        set {
            guard let newURL = newValue else { return }
            
            if let scheme = newURL.scheme {
                urlProtocol = HttpProtocol(rawValue: scheme) ?? .http
            }
            if let host = newURL.host {
                urlHostname = host
            }
            if let port = newURL.port {
                urlPort = String(port)
            }
        }
    }
}

enum HttpProtocol: String, CaseIterable {
    case http = "http"
    case https = "https"
}

enum DefaultsKeys: String {
    case urlProtocol = "URL-Protocol"
    case urlHostname = "URL-Hostname"
    case urlPort = "URL-Port"
    case usersName = "Users-Name"
    case sessionID = "Session-ID"
    case userID = "User-ID"
    case accessToken = "Access-Token"
    case serverID = "Server-ID"
}
