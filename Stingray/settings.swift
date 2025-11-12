//
//  settings.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

@Observable
final class SettingsManager {
    private let defaults = UserDefaults.standard
    
    var urlProtocol: String {
        didSet { defaults.set(urlProtocol, forKey: "URL-protocol") }
    }
    
    var urlHostname: String {
        didSet { defaults.set(urlHostname, forKey: "URL-hostname") }
    }
    
    var urlPort: String {
        didSet { defaults.set(urlPort, forKey: "URL-port") }
    }
    
    init() {
        self.urlProtocol = defaults.string(forKey: "URL-protocol") ?? "http"
        self.urlHostname = defaults.string(forKey: "URL-hostname") ?? ""
        self.urlPort = defaults.string(forKey: "URL-port") ?? "8096"
    }
    
    var url: URL? {
        get {
            if urlProtocol == "" || urlHostname == "" {
                return nil
            }
            return URL(string: "\(urlProtocol)://\(urlHostname):\(urlPort)/")
        }
        set {
            guard let newURL = newValue else { return }
            
            if let scheme = newURL.scheme {
                urlProtocol = scheme
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
