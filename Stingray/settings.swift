//
//  settings.swift
//  Stingray
//
//  Created by Ben Roberts on 11/12/25.
//

import SwiftUI

final class SettingsManager {
    @AppStorage("URL-protocol") var urlProtocol: String = ""
    @AppStorage("URL-hostname") var urlHostname: String = ""
    @AppStorage("URL-port") var urlPort: Int = 8096
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
                urlPort = port
            }
        }
    }
}
